module main

fn body_has_direct_yield(stmts []Stmt) bool {
	return has_direct_yield(stmts)
}

fn body_has_direct_return_value(stmts []Stmt) bool {
	return has_direct_return_value(stmts)
}

fn has_direct_return_value[T](node T) bool {
	$if T is FunctionDef || T is AsyncFunctionDef || T is ClassDef || T is Lambda {
		return false
	} $else $if T is Return {
		return node.value != none
	} $else $if T is $option {
		if val := node {
			return has_direct_return_value(val)
		}
	} $else $if T is $pointer {
		return has_direct_return_value(*node)
	} $else $if T is $array {
		for item in node {
			if has_direct_return_value(item) {
				return true
			}
		}
	} $else $if T is $sumtype {
		$for variant in T.variants {
			if node is variant {
				return has_direct_return_value(node)
			}
		}
	} $else $if T is $struct {
		$for field in T.fields {
			if has_direct_return_value(node.$(field.name)) {
				return true
			}
		}
	}
	return false
}

fn has_direct_yield[T](node T) bool {
	$if T is FunctionDef || T is AsyncFunctionDef || T is ClassDef || T is Lambda {
		return false
	} $else $if T is Yield || T is YieldFrom {
		return true
	} $else $if T is $option {
		if val := node {
			return has_direct_yield(val)
		}
	} $else $if T is $pointer {
		return has_direct_yield(*node)
	} $else $if T is $array {
		for item in node {
			if has_direct_yield(item) {
				return true
			}
		}
	} $else $if T is $sumtype {
		$for variant in T.variants {
			if node is variant {
				return has_direct_yield(node)
			}
		}
	} $else $if T is $struct {
		$for field in T.fields {
			if has_direct_yield(node.$(field.name)) {
				return true
			}
		}
	}
	return false
}

// Channel producers run concurrently with consumers. Calls and structured
// cleanup can be observably reordered across a yield; refuse those loops
// until the generator ABI provides a consumer-resume handshake.
fn (t VTranspiler) generator_needs_sequential_resume[T](node T) bool {
	$if T is FunctionDef || T is AsyncFunctionDef || T is ClassDef || T is Lambda {
		return false
	} $else $if T is Call {
		if node.func is Name && (node.func as Name).id == 'range'
			&& node.keywords.len == 0 && 'range' !in t.module_functions
			&& !t.is_bound_in_scope('range') {
			return t.generator_needs_sequential_resume(node.args)
		}
		return true
	} $else $if T is Try || T is With || T is AsyncWith || T is Raise || T is YieldFrom {
		return true
	} $else $if T is Return {
		if node.value != none {
			return true
		}
	} $else $if T is $option {
		if value := node {
			return t.generator_needs_sequential_resume(value)
		}
	} $else $if T is $pointer {
		return t.generator_needs_sequential_resume(*node)
	} $else $if T is $array {
		for item in node {
			if t.generator_needs_sequential_resume(item) {
				return true
			}
		}
	} $else $if T is $sumtype {
		$for variant in T.variants {
			if node is variant {
				return t.generator_needs_sequential_resume(node)
			}
		}
	} $else $if T is $struct {
		$for field in T.fields {
			if t.generator_needs_sequential_resume(node.$(field.name)) {
				return true
			}
		}
	}
	return false
}

fn record_used_name(name string, mut used map[string]bool) {
	if name == '' {
		return
	}
	used[name] = true
	used[escape_local_decl(name)] = true
}

fn collect_scope_names[T](node T, mut used map[string]bool) {
	$if T is FunctionDef {
		record_used_name(node.name, mut used)
		return
	} $else $if T is AsyncFunctionDef {
		record_used_name(node.name, mut used)
		return
	} $else $if T is ClassDef {
		record_used_name(node.name, mut used)
		return
	} $else $if T is Name {
		record_used_name(node.id, mut used)
		return
	} $else $if T is ExceptHandler {
		if name := node.name {
			record_used_name(name, mut used)
		}
		collect_scope_names(node.body, mut used)
		return
	} $else $if T is MatchAs {
		if name := node.name {
			record_used_name(name, mut used)
		}
		collect_scope_names(node.pattern, mut used)
		return
	} $else $if T is MatchStar {
		if name := node.name {
			record_used_name(name, mut used)
		}
		return
	} $else $if T is MatchMapping {
		if rest := node.rest {
			record_used_name(rest, mut used)
		}
		collect_scope_names(node.patterns, mut used)
		return
	} $else $if T is Global || T is Nonlocal {
		for name in node.names {
			record_used_name(name, mut used)
		}
		return
	} $else $if T is $option {
		if val := node {
			collect_scope_names(val, mut used)
		}
	} $else $if T is $pointer {
		collect_scope_names(*node, mut used)
	} $else $if T is $array {
		for item in node {
			collect_scope_names(item, mut used)
		}
	} $else $if T is $sumtype {
		$for variant in T.variants {
			if node is variant {
				collect_scope_names(node, mut used)
			}
		}
	} $else $if T is $struct {
		$for field in T.fields {
			collect_scope_names(node.$(field.name), mut used)
		}
	}
}

// generator_channel_name returns the active generator's V channel parameter name.
fn (t VTranspiler) generator_channel_name() string {
	return if t.current_gen_ch != '' { t.current_gen_ch } else { 'ch' }
}

// pick_generator_channel_name selects a channel parameter spelling that cannot
// collide with any parameter, local binding, or referenced name in the generator.
fn (t VTranspiler) pick_generator_channel_name(args Arguments, body []Stmt) string {
	mut used := map[string]bool{}
	mut params := args.posonlyargs.clone()
	params << args.args
	params << args.kwonlyargs
	for arg in params {
		record_used_name(arg.arg, mut used)
		used[escape_identifier(arg.arg)] = true
	}
	if arg := args.vararg {
		record_used_name(arg.arg, mut used)
	}
	if arg := args.kwarg {
		record_used_name(arg.arg, mut used)
	}
	collect_scope_names(body, mut used)
	if 'ch' !in used {
		return 'ch'
	}
	mut n := 0
	for {
		cand := if n == 0 { 'py2v_gen_ch' } else { 'py2v_gen_ch_${n}' }
		if cand !in used {
			return cand
		}
		n++
	}
}

// infer_generator_yield_type_for seeds parameter types before scanning the
// generator body so forward-declared and cross-module generators infer the
// same channel element type as when emitted in visit_function_def.
fn (mut t VTranspiler) infer_generator_yield_type_for(args Arguments, body []Stmt, is_method bool, decorator_kind string) string {
	saved_vars := t.var_types.clone()
	defer { t.var_types = saved_vars }
	mut params := args.posonlyargs.clone()
	params << args.args
	params << args.kwonlyargs
	for arg in params {
		if is_method && (arg.arg == 'self' || (arg.arg == 'cls' && decorator_kind == 'classmethod')) {
			continue
		}
		mut typ := ''
		if ann := arg.annotation {
			typ = t.typename_from_annotation(*ann)
		} else if arg.v_annotation != '' {
			typ = t.map_type(arg.v_annotation)
		}
		if typ != '' {
			t.var_types[arg.arg] = typ
		}
	}
	if vararg := args.vararg {
		mut typ := if ann := vararg.annotation { t.typename_from_annotation(*ann) } else { '' }
		if typ == '' {
			typ = 'Any'
		}
		t.var_types[vararg.arg] = '[]' + typ.trim_left('.')
	}
	return t.infer_generator_yield_type(body)
}

// prescan_generators records module-level, nested, and class-method generator
// signatures before function bodies are emitted so forward calls, method calls,
// and local aliases resolve both the channel element type and argument order.
fn (mut t VTranspiler) prescan_generators(stmts []Stmt) {
	for stmt in stmts {
		match stmt {
			FunctionDef {
				if stmt.is_generator && body_has_direct_yield(stmt.body) {
					yt := t.infer_generator_yield_type_for(stmt.args, stmt.body, false,
						stmt.decorator_kind)
					t.generator_signatures[stmt.name] = GeneratorSignature{yt, stmt.args, false, '', t.generator_needs_sequential_resume(stmt.body)}
				}
			}
			AsyncFunctionDef {
				if stmt.is_generator && body_has_direct_yield(stmt.body) {
					yt := t.infer_generator_yield_type_for(stmt.args, stmt.body, false,
						stmt.decorator_kind)
					t.generator_signatures[stmt.name] = GeneratorSignature{yt, stmt.args, false, '', t.generator_needs_sequential_resume(stmt.body)}
				}
			}
			ClassDef {
				for member in stmt.body {
					match member {
						FunctionDef {
							if member.is_generator && body_has_direct_yield(member.body) {
								yt := t.infer_generator_yield_type_for(member.args, member.body,
									true, member.decorator_kind)
								static_cls := if member.decorator_kind in [
									'staticmethod',
									'classmethod',
								] {
									stmt.name
								} else {
									''
								}
								t.generator_signatures['${stmt.name}.${member.name}'] = GeneratorSignature{yt, member.args, member.decorator_kind != 'staticmethod', static_cls, t.generator_needs_sequential_resume(member.body)}
							}
						}
						AsyncFunctionDef {
							if member.is_generator && body_has_direct_yield(member.body) {
								yt := t.infer_generator_yield_type_for(member.args, member.body,
									true, member.decorator_kind)
								static_cls := if member.decorator_kind in [
									'staticmethod',
									'classmethod',
								] {
									stmt.name
								} else {
									''
								}
								t.generator_signatures['${stmt.name}.${member.name}'] = GeneratorSignature{yt, member.args, member.decorator_kind != 'staticmethod', static_cls, t.generator_needs_sequential_resume(member.body)}
							}
						}
						else {}
					}
				}
			}
			else {}
		}
	}
}

// register_generator_signatures records every generator function and method in
// a multi-module package before pass 2 emits importing modules.
fn register_generator_signatures(parsed map[string]Module, mut registry ModuleRegistry) {
	mut keys := parsed.keys()
	keys.sort()
	for key in keys {
		mut scan := new_transpiler()
		scan.registry = registry
		scan.current_dotted = key
		scan.prescan_generators(parsed[key]!.body)
		for name, sig in scan.generator_signatures {
			registry.generator_signatures['${key}.${name}'] = sig
		}
	}
}

fn (t VTranspiler) lookup_registry_generator(mod_dotted string, symbol string) ?GeneratorSignature {
	if sig := t.registry.generator_signatures['${mod_dotted}.${symbol}'] {
		return sig
	}
	info := t.registry.lookup(mod_dotted)
	if info.dotted != '' {
		if sig := t.registry.generator_signatures['${info.dotted}.${symbol}'] {
			return sig
		}
	}
	return none
}

fn (mut t VTranspiler) resolve_class_generator(class_name string, method string) ?GeneratorSignature {
	mut seen := map[string]bool{}
	mut queue := [class_name]
	for queue.len > 0 {
		cls := queue.pop()
		if cls == '' || cls in seen {
			continue
		}
		seen[cls] = true
		if sig := t.generator_signatures['${cls}.${method}'] {
			return sig
		}
		if bases := t.class_base_names[cls] {
			queue << bases
		}
	}
	return none
}

// resolve_generator_signature finds the GeneratorSignature for a bare name,
// local alias, imported generator, or method call on a known class.
fn (mut t VTranspiler) resolve_generator_signature(callee Expr) ?GeneratorSignature {
	match callee {
		Name {
			if sig := t.generator_aliases[callee.id] {
				return sig
			}
			if callee.id in t.non_generator_locals {
				return none
			}
			if sig := t.generator_signatures[callee.id] {
				return sig
			}
			if path := t.init_import_aliases[callee.id] {
				if dot := path.last_index('.') {
					return t.lookup_registry_generator(path[..dot], path[dot + 1..])
				}
			}
			return none
		}
		Attribute {
			if callee.value is Name {
				base := (callee.value as Name).id
				if sibling := t.submodule_aliases[base] {
					if sig := t.lookup_registry_generator(sibling, callee.attr) {
						return sig
					}
				}
				if mod_path := t.init_import_aliases[base] {
					if sig := t.lookup_registry_generator(mod_path, callee.attr) {
						return sig
					}
				}
				if v_mod := t.import_aliases[base] {
					mod_dotted := t.registry.dotted_for_v_module(v_mod)
					if mod_dotted != '' {
						if sig := t.lookup_registry_generator(mod_dotted, callee.attr) {
							return sig
						}
					}
				}
				if base == 'self' && t.current_class_name != '' {
					if sig := t.resolve_class_generator(t.current_class_name, callee.attr) {
						return sig
					}
				}
				if base in t.known_classes || base in t.module_class_names {
					if sig := t.resolve_class_generator(base, callee.attr) {
						return sig
					}
				}
			}
			mut recv_type := t.infer_expr_type(*callee.value)
			if recv_type == '' && callee.value is Name {
				recv_type = t.var_types[(callee.value as Name).id] or { '' }
			}
			if recv_type == '' && callee.value is Call {
				recv_type = t.constructor_name(callee.value as Call)
			}
			recv_type = recv_type.trim_left('&?').all_before('[')
			if recv_type != '' {
				if dot := recv_type.last_index('.') {
					mod_dotted := t.registry.dotted_for_v_module(recv_type[..dot])
					if mod_dotted != '' {
						if sig := t.lookup_registry_generator(mod_dotted,
							'${recv_type[dot + 1..]}.${callee.attr}') {
							return sig
						}
					}
				}
				if sig := t.resolve_class_generator(recv_type, callee.attr) {
					return sig
				}
				if recv_type.starts_with('Py2v_') {
					if sig := t.resolve_class_generator(recv_type['Py2v_'.len..], callee.attr) {
						return sig
					}
				}
			}
			return none
		}
		else {
			return none
		}
	}
}

struct PreparedGeneratorCall {
	producer   string
	ch_type    string
	arg_prefix []string
	args       []string
	valid      bool
}

// prepare_generator_call binds arguments for a generator invocation with the
// channel slot always first. Unknown generators with keyword arguments are
// refused rather than binding keywords positionally.
fn (mut t VTranspiler) prepare_generator_call(call Call, sig ?GeneratorSignature, iter_renames ?map[string]string) PreparedGeneratorCall {
	saved_renames := t.renamed_idents
	if before := iter_renames {
		t.renamed_idents = before
	}
	defer { t.renamed_idents = saved_renames }

	mut producer := t.visit_expr(*call.func)
	mut elem_type := t.infer_iter_elem_type(Expr(call))
	mut producer_args := []string{}
	mut arg_prefix := []string{}
	mut ordered := false
	if found := sig {
		if found.static_class != '' {
			if call.func !is Attribute {
				return PreparedGeneratorCall{}
			}
			member := call.func as Attribute
			if renamed := t.renamed_static_member(member) {
				producer = renamed
			} else if member.value is Name {
				receiver := (member.value as Name).id
				owner := t.local_class_name(found.static_class)
				receiver_type := t.infer_expr_type(member.value)
				if receiver != found.static_class && receiver_type !in [
					found.static_class,
					owner,
				] {
					return PreparedGeneratorCall{}
				}
				method_name := escape_keyword(escape_leading_underscore(member.attr))
				producer = if !t.nominal_enums[found.static_class]
					&& '${t.current_dotted}.${found.static_class}' in t.registry.class_names {
					'${to_symbol_ident(owner)}_${escape_leading_underscore(member.attr)}'
				} else {
					'${owner}.${method_name}'
				}
			} else {
				return PreparedGeneratorCall{}
			}
		}
		elem_type = found.yield_type
		if found.args.kwonlyargs.len > 0 || found.args.defaults.len > 0 || call.keywords.len > 0 {
			bound := t.ordered_generator_call(call, found)
			if !bound.valid {
				return PreparedGeneratorCall{}
			}
			arg_prefix = bound.prefix
			producer_args = bound.ordered
			ordered = true
		}
	} else if call.keywords.len > 0 {
		return PreparedGeneratorCall{}
	}
	if !ordered {
		for arg in call.args {
			if arg is Starred {
				return PreparedGeneratorCall{}
			}
			producer_args << t.visit_expr(arg)
		}
	}
	ch_type := if elem_type.len > 0 { elem_type } else { 'Any' }
	return PreparedGeneratorCall{
		producer:   producer
		ch_type:    ch_type
		arg_prefix: arg_prefix
		args:       producer_args
		valid:      true
	}
}

// collect_generator_call lowers `list(gen(...))` / `tuple(gen(...))` on a
// known generator into a plain-V IIFE that drains the channel into a slice.
fn (mut t VTranspiler) collect_generator_call(call Call, sig GeneratorSignature) string {
	mut refs := InitArgumentRefs{}
	collect_init_argument_refs(Expr(call), mut refs)
	if refs.scoped {
		return 'py2v_unsupported_generator_arguments()'
	}
	prep := t.prepare_generator_call(call, sig, none)
	if !prep.valid {
		return 'py2v_unsupported_generator_arguments()'
	}
	mutated := t.init_mutated_argument_names(refs.calls)
	mut captures := []string{}
	mut seen_caps := map[string]bool{}
	mut ref_names := refs.names.keys()
	ref_names.sort()
	for raw_name in ref_names {
		name := refs.names[raw_name]
		if !t.init_argument_local(name) {
			continue
		}
		emitted := t.visit_name(name)
		cap := if emitted.starts_with('(*') && emitted.ends_with(')') {
			emitted[2..emitted.len - 1]
		} else if name.id in mutated {
			'mut ${emitted}'
		} else {
			emitted
		}
		if cap !in seen_caps {
			seen_caps[cap] = true
			captures << cap
		}
	}
	ch := t.new_tmp('ch')
	items := t.new_tmp('items')
	val := t.new_tmp('val')
	mut call_args := [ch]
	call_args << prep.args
	cap_list := if captures.len > 0 { ' [${captures.join(', ')}]' } else { '' }
	mut lines := ['fn${cap_list} () []${prep.ch_type} {']
	for line in prep.arg_prefix {
		lines << '\t${line}'
	}
	lines << '\t${ch} := chan ${prep.ch_type}{}'
	lines << '\tgo ${prep.producer}(${call_args.join(', ')})'
	lines << '\tmut ${items} := []${prep.ch_type}{}'
	lines << '\tfor {'
	lines << '\t\t${val} := <-${ch} or { break }'
	lines << '\t\t${items} << ${val}'
	lines << '\t}'
	lines << '\treturn ${items}'
	lines << '}()'
	return lines.join('\n')
}
