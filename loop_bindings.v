module main

// LoopScopeState holds per-function escaping loop-binding, vararg-rebind,
// and unbound-target tracking.
struct LoopScopeState {
mut:
	vararg_params           map[string]string
	boxed_vararg_decls      map[string]string
	boxed_vararg_vars       map[string]bool
	unbound_guard_flags     map[string]string
	unbound_guard_order     []string
	guard_conditional_loads bool
}

fn comp_parts(expr Expr) ?([]Comprehension, []Expr) {
	return match expr {
		ListComp { expr.generators, [*expr.elt] }
		SetComp { expr.generators, [*expr.elt] }
		DictComp { expr.generators, [*expr.key, *expr.value] }
		GeneratorExp { expr.generators, [*expr.elt] }
		else { none }
	}
}

fn for_target_name_nodes(target Expr) []Name {
	return match target {
		Name { [target] }
		Tuple, List {
			mut out := []Name{}
			for e in target.elts {
				out << for_target_name_nodes(e)
			}
			out
		}
		Starred { for_target_name_nodes(*target.value) }
		else { [] }
	}
}

fn opt_name_eq(opt ?string, name string) bool {
	return if val := opt { val == name } else { false }
}

fn pattern_binds_name(pattern MatchPattern, name string) bool {
	return match pattern {
		MatchAs {
			opt_name_eq(pattern.name, name)
				|| (pattern.pattern != none && pattern_binds_name(*pattern.pattern, name))
		}
		MatchStar { opt_name_eq(pattern.name, name) }
		MatchMapping {
			opt_name_eq(pattern.rest, name) || pattern.patterns.any(pattern_binds_name(it, name))
		}
		MatchSequence, MatchOr { pattern.patterns.any(pattern_binds_name(it, name)) }
		MatchClass {
			pattern.patterns.any(pattern_binds_name(it, name))
				|| pattern.kwd_patterns.any(pattern_binds_name(it, name))
		}
		else { false }
	}
}

fn stmt_assign_targets(stmt Stmt) []Expr {
	return if stmt is Assign {
		stmt.targets
	} else if stmt is AnnAssign && stmt.value != none {
		[*stmt.target]
	} else {
		[]Expr{}
	}
}

fn opt_exprs(items ...?&Expr) []Expr {
	mut out := []Expr{}
	for item in items {
		if e := item {
			out << *e
		}
	}
	return out
}

fn stmt_header_exprs(stmt Stmt) []Expr {
	return match stmt {
		Assign, ExprStmt { [*stmt.value] }
		AnnAssign { opt_exprs(stmt.value) }
		AugAssign { [stmt.value] }
		Return { opt_exprs(stmt.value) }
		Assert { opt_exprs(stmt.test, stmt.msg) }
		Raise { opt_exprs(stmt.exc, stmt.cause) }
		If, While { [*stmt.test] }
		For, AsyncFor { [*stmt.iter] }
		Match { [*stmt.subject] }
		else { [] }
	}
}

fn stmt_child_blocks(stmt Stmt, include_defs bool) [][]Stmt {
	return match stmt {
		If, While, For, AsyncFor { [stmt.body, stmt.orelse] }
		With, AsyncWith { [stmt.body] }
		Try {
			mut blocks := [stmt.body, stmt.orelse, stmt.finalbody]
			for h in stmt.handlers {
				blocks << h.body
			}
			blocks
		}
		Match { stmt.cases.map(it.body) }
		FunctionDef, AsyncFunctionDef {
			if include_defs { [stmt.body] } else { [][]Stmt{} }
		}
		else { [] }
	}
}

fn with_item_binds(item WithItem, name string) bool {
	return if vars := item.optional_vars { name in for_target_names(*vars) } else { false }
}

fn args_defaults_read(args Arguments, name string) bool {
	return args.defaults.any(loop_expr_reads_name(it, name, false))
		|| args.kw_defaults.any(if val := it {
			loop_expr_reads_name(val, name, false)
		} else {
			false
		})
}

fn loop_expr_reads_name(expr Expr, name string, uncond bool) bool {
	if gens, tail := comp_parts(expr) {
		for i, g in gens {
			if loop_expr_reads_name(*g.iter, name, uncond) {
				return true
			}
			if (uncond && i == 0) || name in for_target_names(*g.target) {
				return false
			}
			if g.ifs.any(loop_expr_reads_name(it, name, uncond)) {
				return true
			}
		}
		return !uncond && tail.any(loop_expr_reads_name(it, name, false))
	}
	return match expr {
		Name { expr.id == name }
		NamedExpr { loop_expr_reads_name(*expr.value, name, uncond) }
		IfExp {
			loop_expr_reads_name(*expr.test, name, uncond) || (!uncond
				&& (loop_expr_reads_name(*expr.body, name, false)
					|| loop_expr_reads_name(*expr.orelse, name, false)))
		}
		BoolOp {
			if uncond {
				expr.values.len > 0 && loop_expr_reads_name(expr.values[0], name, true)
			} else {
				expr.values.any(loop_expr_reads_name(it, name, false))
			}
		}
		Lambda {
			binds := expr.args.posonlyargs.any(it.arg == name)
				|| expr.args.args.any(it.arg == name)
				|| expr.args.kwonlyargs.any(it.arg == name)
				|| (if v := expr.args.vararg { v.arg == name } else { false })
				|| (if k := expr.args.kwarg { k.arg == name } else { false })
			args_defaults_read(expr.args, name)
				|| (!uncond && !binds && loop_expr_reads_name(*expr.body, name, false))
		}
		else { condition_walrus_children(expr).any(loop_expr_reads_name(it, name, uncond)) }
	}
}

fn target_reads_name(target Expr, name string) bool {
	return match target {
		Name { false }
		Tuple, List { target.elts.any(target_reads_name(it, name)) }
		Starred { target_reads_name(*target.value, name) }
		else { loop_expr_reads_name(target, name, false) }
	}
}

fn body_deletes_name(stmts []Stmt, name string) bool {
	for stmt in stmts {
		if stmt is Delete && stmt.targets.any(name in for_target_names(it)) {
			return true
		}
		if stmt_child_blocks(stmt, false).any(body_deletes_name(it, name)) {
			return true
		}
	}
	return false
}

fn stmt_definitely_exits(stmt Stmt) bool {
	return match stmt {
		Return, Raise, Break, Continue { true }
		If {
			stmt.orelse.len > 0 && stmt.body.any(stmt_definitely_exits(it))
				&& stmt.orelse.any(stmt_definitely_exits(it))
		}
		else { false }
	}
}

// forced_if_truth resolves literal bools and short-circuiting bool ops whose
// truth value makes one arm of an `if` unreachable.
fn forced_if_truth(test Expr) ?bool {
	if test is Constant && test.value is bool {
		return test.value as bool
	}
	if test is BoolOp {
		if test.op is And && test.values.any(it is Constant && it.value is bool
			&& !(it.value as bool)) {
			return false
		}
		if test.op is Or && test.values.any(it is Constant && it.value is bool
			&& (it.value as bool)) {
			return true
		}
	}
	return none
}

fn stmt_definitely_binds(stmt Stmt, name string, for_kill bool) bool {
	return match stmt {
		Assign { stmt.targets.any(name in for_target_names(it)) }
		AnnAssign { (for_kill || stmt.value != none) && name in for_target_names(*stmt.target) }
		Delete { for_kill && stmt.targets.any(name in for_target_names(it)) }
		Import { for_kill && stmt.names.any((it.asname or { it.name.all_before('.') }) == name) }
		ImportFrom { for_kill && stmt.names.any((it.asname or { it.name }) == name) }
		For, AsyncFor {
			name in for_target_names(stmt.target) && iter_is_statically_nonempty(*stmt.iter)
				&& (for_kill || !body_deletes_name(stmt.body, name))
		}
		If {
			if stmt.test is Constant && stmt.test.value is bool {
				if stmt.test.value as bool {
					stmt.body.any(stmt_definitely_binds(it, name, for_kill))
						&& (for_kill || !body_deletes_name(stmt.body, name))
				} else {
					stmt.orelse.any(stmt_definitely_binds(it, name, for_kill))
						&& (for_kill || !body_deletes_name(stmt.orelse, name))
				}
			} else {
				stmt.orelse.len > 0 && stmt.body.any(stmt_definitely_binds(it, name, for_kill))
					&& stmt.orelse.any(stmt_definitely_binds(it, name, for_kill))
					&& (for_kill || (!body_deletes_name(stmt.body, name)
						&& !body_deletes_name(stmt.orelse, name)))
			}
		}
		With, AsyncWith {
			for_kill && (stmt.items.any(with_item_binds(it, name))
				|| stmt.body.any(stmt_definitely_binds(it, name, true)))
		}
		FunctionDef, AsyncFunctionDef, ClassDef { for_kill && stmt.name == name }
		else { false }
	}
}

fn opt_expr_reads(opt ?&Expr, name string) bool {
	return if e := opt { loop_expr_reads_name(*e, name, false) } else { false }
}

fn loop_stmt_reads_name(stmt Stmt, name string, recurse bool) bool {
	uncond := !recurse
	if stmt_header_exprs(stmt).any(loop_expr_reads_name(it, name, uncond)) {
		return true
	}
	return match stmt {
		Assign, Delete { stmt.targets.any(target_reads_name(it, name)) }
		AnnAssign { target_reads_name(*stmt.target, name) }
		AugAssign { loop_expr_reads_name(*stmt.target, name, false) }
		If {
			if forced := forced_if_truth(*stmt.test) {
				if forced {
					recurse && stmts_read_before_write(stmt.body, name)
				} else {
					recurse && stmts_read_before_write(stmt.orelse, name)
				}
			} else {
				recurse && (stmts_read_before_write(stmt.body, name)
					|| stmts_read_before_write(stmt.orelse, name))
			}
		}
		While {
			recurse && (stmts_read_before_write(stmt.body, name)
				|| stmts_read_before_write(stmt.orelse, name))
		}
		For, AsyncFor {
			bound_target := name in for_target_names(stmt.target)
			target_reads_name(stmt.target, name) || (recurse && ((!bound_target
				&& stmts_read_before_write(stmt.body, name))
				|| ((!bound_target || !iter_is_statically_nonempty(*stmt.iter))
					&& stmts_read_before_write(stmt.orelse, name))))
		}
		With, AsyncWith {
			for item in stmt.items {
				if loop_expr_reads_name(*item.context_expr, name, uncond) {
					return true
				}
				if vars := item.optional_vars {
					if target_reads_name(*vars, name) {
						return true
					}
					if name in for_target_names(*vars) {
						return false
					}
				}
			}
			recurse && stmts_read_before_write(stmt.body, name)
		}
		Try {
			recurse && (stmts_read_before_write(stmt.body, name)
				|| stmts_read_before_write(stmt.orelse, name)
				|| stmts_read_before_write(stmt.finalbody, name)
				|| stmt.handlers.any(opt_expr_reads(it.typ, name)
					|| (!opt_name_eq(it.name, name) && stmts_read_before_write(it.body, name))))
		}
		Match {
			recurse && stmt.cases.any(!pattern_binds_name(it.pattern, name)
				&& (opt_expr_reads(it.guard, name) || stmts_read_before_write(it.body, name)))
		}
		FunctionDef, AsyncFunctionDef {
			stmt.decorator_list.any(loop_expr_reads_name(it, name, uncond))
				|| args_defaults_read(stmt.args, name) || (recurse && name in stmt.capture_names)
		}
		ClassDef {
			stmt.decorator_list.any(loop_expr_reads_name(it, name, uncond))
				|| stmt.bases.any(loop_expr_reads_name(it, name, uncond))
				|| stmt.keywords.any(loop_expr_reads_name(it.value, name, uncond))
		}
		else { false }
	}
}

fn stmts_read_before_write(stmts []Stmt, name string) bool {
	for stmt in stmts {
		if loop_stmt_reads_name(stmt, name, true) {
			return true
		}
		if stmt_definitely_binds(stmt, name, true) || stmt_definitely_exits(stmt) {
			return false
		}
	}
	return false
}

fn inert_loop_zero_value(typ string) ?string {
	if typ == 'Any' {
		return 'pyrt.none_'
	}
	if typ.starts_with('?') {
		return '${typ}(none)'
	}
	if typ in v_width_rank {
		return if typ == 'int' { '0' } else { '${typ}(0)' }
	}
	if typ in ['bool', 'string'] || typ.starts_with('[]') || typ.starts_with('map[') {
		return zero_value_for_type(typ)
	}
	return none
}

fn (mut t VTranspiler) infer_escaping_target_type(target Expr, target_node Name, iter Expr) string {
	if ann := target_node.v_annotation {
		mapped := t.map_type(ann)
		if mapped != '' && mapped != 'auto' {
			return mapped
		}
	}
	if target is Name {
		elem := t.infer_iter_elem_type(iter)
		if elem != '' {
			return elem
		}
		if iter is Tuple && iter.elts.len > 0 {
			return t.infer_expr_type(iter.elts[0])
		}
	}
	return ''
}

fn (mut t VTranspiler) activate_boxed_vararg(name string) {
	decl := t.loop_state.boxed_vararg_decls[name] or { return }
	if t.loop_state.boxed_vararg_vars[name] {
		return
	}
	t.local_idents[name] = decl
	t.scope_idents[decl] = name
	t.var_types[name] = 'Any'
	t.param_idents[name] = true
	t.any_parameter_names[name] = true
	t.loop_state.boxed_vararg_vars[name] = true
}

fn (mut t VTranspiler) predeclare_escaping_block(top Stmt, block []Stmt, mut shadowed map[string]bool, mut decls []string, mut pending_varargs []string, after_paths ...[]Stmt) {
	for i, sub in block {
		mut paths := [][]Stmt{}
		if after_paths.len == 0 {
			paths << block[i + 1..].clone()
		} else {
			for a in after_paths {
				mut p := block[i + 1..].clone()
				p << a
				paths << p
			}
		}
		t.predeclare_escaping_stmt(top, sub, paths, mut shadowed, mut decls, mut pending_varargs)
	}
}

fn stmts_paths_read_before_write(paths [][]Stmt, name string) bool {
	return paths.any(stmts_read_before_write(it, name))
}

fn concat_stmts(a []Stmt, b []Stmt) []Stmt {
	mut out := a.clone()
	out << b
	return out
}

fn (mut t VTranspiler) predeclare_escaping_stmt(top Stmt, stmt Stmt, rest_paths [][]Stmt, mut shadowed map[string]bool, mut decls []string, mut pending_varargs []string) {
	match stmt {
		For, AsyncFor {
			for tn in for_target_name_nodes(stmt.target) {
				name := tn.id
				if name == '_' || name in shadowed || name in t.global_vars
					|| t.condition_walrus_vars[name]
					|| t.binding_spelling(name) in t.loop_idents {
					continue
				}
				if body_deletes_name(stmt.body, name)
					&& (stmts_read_before_write(stmt.orelse, name)
						|| stmts_paths_read_before_write(rest_paths, name)) {
					decls << t.unsupported_site('deleted_loop_target',
						'deleted loop target can be unbound at a later load', '')
					continue
				}
				is_vararg := name in t.loop_state.vararg_params
					&& name !in t.loop_state.boxed_vararg_decls
					&& !t.loop_state.boxed_vararg_vars[name]
				if (!is_vararg && t.is_bound_in_scope(name))
					|| (!stmts_read_before_write(stmt.orelse, name)
						&& !stmts_paths_read_before_write(rest_paths, name)) {
					continue
				}
				typ := if is_vararg {
					'Any'
				} else {
					t.infer_escaping_target_type(stmt.target, tn, *stmt.iter)
				}
				init := if is_vararg {
					orig := t.binding_spelling(name)
					elem_box := if t.loop_state.vararg_params[name] == 'Any' {
						orig
					} else {
						'${orig}.map(pyrt.box(it))'
					}
					'Any(pyrt.new_tuple(${elem_box}))'
				} else {
					inert_loop_zero_value(typ) or { continue }
				}
				base := escape_local_decl(name)
				decl := if is_vararg {
					t.new_tmp('param_rebind')
				} else if base in t.scope_idents || base in t.loop_idents {
					t.fresh_loop_ident(base, map[string]string{})
				} else {
					base
				}
				if typ == 'Any' {
					t.generated_code_has_any_type = true
					t.add_using('pyrt')
				}
				decls << 'mut ${decl} := ${init}'
				if is_vararg {
					// Keep the original `...T` slice active for pre-loop reads
					// (e.g. `len(values)` or `range(len(args))`); switch `name`
					// to the boxed local only once the rebinding loop begins or
					// after the enclosing top statement exits.
					t.loop_state.boxed_vararg_decls[name] = decl
					pending_varargs << name
				} else {
					t.local_idents[name] = decl
					t.scope_idents[decl] = name
					t.var_types[name] = typ
					if !stmt_definitely_binds(top, name, false) {
						flag := t.new_tmp('bound')
						t.loop_state.unbound_guard_flags[name] = flag
						t.loop_state.unbound_guard_order << name
						decls << 'mut ${flag} := false'
					}
				}
			}
			mut added := []string{}
			for tn in for_target_name_nodes(stmt.target) {
				if tn.id !in shadowed {
					shadowed[tn.id] = true
					added << tn.id
				}
			}
			mut body_after := [stmt.body]
			for rp in rest_paths {
				body_after << concat_stmts(stmt.orelse, rp)
			}
			t.predeclare_escaping_block(top, stmt.body, mut shadowed, mut decls, mut pending_varargs,
				...body_after)
			for name in added {
				shadowed.delete(name)
			}
			t.predeclare_escaping_block(top, stmt.orelse, mut shadowed, mut decls, mut pending_varargs,
				...rest_paths)
		}
		While {
			mut body_after := [concat_stmts([Stmt(ExprStmt{ value: stmt.test })], stmt.body)]
			for rp in rest_paths {
				body_after << concat_stmts(stmt.orelse, rp)
			}
			t.predeclare_escaping_block(top, stmt.body, mut shadowed, mut decls, mut pending_varargs,
				...body_after)
			t.predeclare_escaping_block(top, stmt.orelse, mut shadowed, mut decls, mut pending_varargs,
				...rest_paths)
		}
		Try {
			mut try_after := [][]Stmt{}
			mut handler_after := [][]Stmt{}
			for rp in rest_paths {
				try_after << concat_stmts(stmt.orelse, concat_stmts(stmt.finalbody, rp))
				handler_after << concat_stmts(stmt.finalbody, rp)
			}
			t.predeclare_escaping_block(top, stmt.body, mut shadowed, mut decls, mut pending_varargs,
				...try_after)
			for h in stmt.handlers {
				t.predeclare_escaping_block(top, h.body, mut shadowed, mut decls, mut pending_varargs,
					...handler_after)
			}
			t.predeclare_escaping_block(top, stmt.orelse, mut shadowed, mut decls, mut pending_varargs,
				...handler_after)
			t.predeclare_escaping_block(top, stmt.finalbody, mut shadowed, mut decls, mut pending_varargs,
				...rest_paths)
		}
		else {
			for block in stmt_child_blocks(stmt, false) {
				t.predeclare_escaping_block(top, block, mut shadowed, mut decls, mut pending_varargs,
					...rest_paths)
			}
		}
	}
}

fn iter_is_statically_nonempty(iter Expr) bool {
	if iter is List {
		return iter.elts.any(it !is Starred)
	}
	if iter is Tuple {
		return iter.elts.any(it !is Starred)
	}
	if iter is Set {
		return iter.elts.any(it !is Starred)
	}
	if iter is Constant {
		return iter.value is string && (iter.value as string).len > 0
	}
	if iter is Call && iter.func is Name && iter.func.id == 'range' && iter.keywords.len == 0 {
		mut nums := []i64{}
		for arg in iter.args {
			nums << literal_signed_integer(arg) or { return false }
		}
		return match nums.len {
			1 { nums[0] > 0 }
			2 { nums[0] < nums[1] }
			3 { (nums[2] > 0 && nums[0] < nums[1]) || (nums[2] < 0 && nums[0] > nums[1]) }
			else { false }
		}
	}
	return false
}

fn format_bound_flag_assign(flag string, val string) string {
	if flag.starts_with('(*') && flag.ends_with(')') {
		return 'unsafe { ${flag} = ${val} }'
	}
	return '${flag} = ${val}'
}

fn format_bound_flag_read(flag string) string {
	if flag.starts_with('(*') && flag.ends_with(')') {
		return 'unsafe { ${flag} }'
	}
	return flag
}

fn format_bound_flag_addr(flag string) string {
	if flag.starts_with('(*') && flag.ends_with(')') {
		return flag[2..flag.len - 1]
	}
	return '&${flag}'
}

// predeclare_and_guard emits predeclarations for escaping loop targets plus
// unbound-local checks before `stmt`.
fn (mut t VTranspiler) predeclare_and_guard(stmt Stmt, rest []Stmt) ([]string, []string) {
	mut shadowed := map[string]bool{}
	mut out := []string{}
	mut pending_varargs := []string{}
	t.predeclare_escaping_stmt(stmt, stmt, [rest], mut shadowed, mut out, mut pending_varargs)
	for name in t.loop_state.unbound_guard_order {
		if name !in t.renamed_idents && loop_stmt_reads_name(stmt, name, false) {
			if flag := t.loop_state.unbound_guard_flags[name] {
				out << "if !${format_bound_flag_read(flag)} { ${t.runtime_helper('unbound_local')}('${name}') }"
			}
		}
	}
	return out, pending_varargs
}

fn (mut t VTranspiler) visit_stmt_in_block(stmt Stmt, rest []Stmt, pending_varargs []string) string {
	saved_rest := t.stmt_rest
	t.stmt_rest = rest
	s := t.visit_stmt(stmt)
	t.stmt_rest = saved_rest
	for name in pending_varargs {
		t.activate_boxed_vararg(name)
	}
	return s
}

fn (t VTranspiler) unbound_post_updates(stmt Stmt) []string {
	is_delete := stmt is Delete
	targets := if stmt is Delete { stmt.targets } else { stmt_assign_targets(stmt) }
	val := if is_delete { 'false' } else { 'true' }
	mut out := []string{}
	for target in targets {
		for name in for_target_names(target) {
			if is_delete || name !in t.renamed_idents {
				if flag := t.loop_state.unbound_guard_flags[name] {
					out << format_bound_flag_assign(flag, val)
				}
			}
		}
	}
	return out
}

// orelse_declared_names returns every local binding an `orelse` clause
// introduces into its enclosing V block.
fn orelse_declared_names(orelse []Stmt) []string {
	mut names := []string{}
	for stmt in orelse {
		match stmt {
			Assign {
				for target in stmt.targets {
					for name in for_target_names(target) {
						if name != '_' && name !in names {
							names << name
						}
					}
				}
			}
			AnnAssign {
				for name in for_target_names(*stmt.target) {
					if name != '_' && name !in names {
						names << name
					}
				}
			}
			FunctionDef, AsyncFunctionDef, ClassDef {
				if stmt.name !in names {
					names << stmt.name
				}
			}
			Import {
				for alias in stmt.names {
					name := alias.asname or { alias.name.all_before('.') }
					if name !in names {
						names << name
					}
				}
			}
			ImportFrom {
				for alias in stmt.names {
					name := alias.asname or { alias.name }
					if name != '*' && name !in names {
						names << name
					}
				}
			}
			else {}
		}
	}
	return names
}

// orelse_needs_block reports whether a breakless for-else introduces new locals
// unused after the loop, so scoping it in a V block prevents type collisions.
fn (t VTranspiler) orelse_needs_block(orelse []Stmt) bool {
	mut declared := []string{}
	for name in orelse_declared_names(orelse) {
		if !t.is_bound_in_scope(name) {
			declared << name
		}
	}
	return declared.len > 0 && !declared.any(stmts_read_before_write(t.stmt_rest, it))
}
