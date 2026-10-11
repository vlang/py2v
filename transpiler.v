module main

const max_generated_line_len = 121

pub struct VTranspiler {
mut:
	tmp_gen TmpVarGen
	usings  []string
	// Maps and state tracked during transpilation
	current_class_name  string
	escaped_identifiers map[string]bool
	extra_mut_vars      map[string]bool
	func_defaults       map[string][]string
	func_param_count    map[string]int
	func_return_types   map[string]string
	// Methods whose receiver must be `mut` in V, keyed ClassName_method.
	mut_receiver_methods        map[string]bool
	generated_code_has_any_type bool
	global_vars                 map[string]bool
	has_global_decl             bool
	mut_param_indices           map[string][]int
	var_types                   map[string]string
	// Pending type notes emitted as // comments before the next function/method
	pending_type_notes []string
	// Class metadata
	class_attr_symbols  map[string]map[string]string
	class_field_escapes map[string]map[string]string
	class_base_names    map[string][]string
	class_direct_fields map[string][]string
	class_type_params   map[string][]string // type_params per class name
	known_classes       map[string][]string
	// Module name for emitted code
	module_name string
	// current_return_count is the arity of the enclosing function's V return
	// tuple, or 0 when it returns a single value.
	current_return_count int
	// Project translation state. `emit_pub` makes top-level symbols visible
	// across V modules; `registry` maps Python module paths to V modules;
	// `current_dotted` is this module's Python dotted path.
	emit_pub       bool
	registry       ModuleRegistry
	current_dotted string
	// import_aliases maps a name bound by `from proj.mod import name` to the V
	// module prefix needed to reach it, e.g. `double` -> `util`.
	import_aliases map[string]string
	// imported_modules records local names bound by module imports, so that
	// `name.attr(...)` is not mistaken for a method call on a value.
	imported_modules map[string]bool
	// imported_classes maps a class name imported from another project module to
	// its field list, so struct literals and base-class checks resolve without
	// transpiling that module first.
	imported_classes map[string][]string
	// path_vars tracks variables known to hold pathlib.Path values (represented as strings)
	path_vars map[string]bool
	// regex_vars tracks variables known to hold compiled regex.RE objects
	regex_vars map[string]bool
	// namedtuple_fields maps struct name → ordered field names for namedtuple() calls
	namedtuple_fields map[string][]string
}

fn emitted_class_name(name string) string {
	if name.len == 1 {
		c := name[0]
		if c >= `A` && c <= `Z` {
			return '${name}_struct'
		}
	}
	return name
}

// new_transpiler creates a new VTranspiler instance
pub fn new_transpiler() VTranspiler {
	return VTranspiler{
		class_attr_symbols:          map[string]map[string]string{}
		class_base_names:            map[string][]string{}
		class_direct_fields:         map[string][]string{}
		class_field_escapes:         map[string]map[string]string{}
		current_class_name:          ''
		escaped_identifiers:         map[string]bool{}
		extra_mut_vars:              map[string]bool{}
		func_defaults:               map[string][]string{}
		func_param_count:            map[string]int{}
		func_return_types:           map[string]string{}
		generated_code_has_any_type: false
		has_global_decl:             false
		global_vars:                 map[string]bool{}
		import_aliases:              map[string]string{}
		imported_modules:            map[string]bool{}
		imported_classes:            map[string][]string{}
		known_classes:               map[string][]string{}
		module_name:                 ''
		current_return_count:        0
		mut_param_indices:           map[string][]int{}
		mut_receiver_methods:        map[string]bool{}
		namedtuple_fields:           map[string][]string{}
		path_vars:                   map[string]bool{}
		regex_vars:                  map[string]bool{}
		tmp_gen:                     new_tmp_var_gen()
		usings:                      []string{}
		var_types:                   map[string]string{}
	}
}

// visit_module emits the top-level V module source for a Module node.
pub fn (mut t VTranspiler) visit_module(node Module) string {
	// Reset per-module state so repeated transpilation with the same instance
	// does not leak global-declaration flags.
	t.has_global_decl = false

	mut module_name := t.module_name
	if module_name.len == 0 {
		module_name = 'main'
	}

	// Buckets — emitted in order: type_decls, struct_decls, func_decls, main_fn
	mut type_decls := []string{} // `type X = ...`, `const ...`
	mut struct_decls := []string{} // `pub struct ...` (from ClassDef)
	mut func_decls := []string{} // `fn ...` (non-main functions)
	mut main_fn_body := []string{} // body lines for fn main()
	mut main_fn_override := '' // full `fn main() {...}` from guard rewrite
	mut comment_lines := []string{} // top-level import comments etc.

	mut first_stmt := true
	for stmt in node.body {
		// Skip module-level docstrings (first bare string constant)
		if first_stmt {
			first_stmt = false
			if stmt is ExprStmt {
				es := stmt as ExprStmt
				if es.value is Constant {
					c := es.value as Constant
					if c.value is string {
						continue
					}
				}
			}
		}
		s := t.visit_stmt(stmt)
		if s.len == 0 {
			continue
		}
		match stmt {
			ClassDef {
				// Class emits struct def + methods; split on first fn boundary
				struct_decls << s
			}
			FunctionDef {
				if stmt.name == 'main' {
					main_fn_override = s
				} else {
					func_decls << s
				}
			}
			AsyncFunctionDef {
				if stmt.name == 'main' {
					main_fn_override = s
				} else {
					func_decls << s
				}
			}
			else {
				trimmed := s.trim_space()
				if trimmed.starts_with('type ') || trimmed.starts_with('const ')
					|| trimmed.starts_with('enum ') {
					type_decls << s
				} else if trimmed.starts_with('pub struct ') || trimmed.starts_with('struct ') {
					struct_decls << s
				} else if stmt is TypeAlias {
					type_decls << s
				} else if trimmed.starts_with('//') {
					// Import comments and similar go before fn main()
					comment_lines << s
				} else {
					main_fn_body << s
				}
			}
		}
	}

	// Any type alias must be first among type_decls
	if t.generated_code_has_any_type {
		type_decls.prepend('type Any = bool | int | i64 | f64 | string | []u8')
	}

	// Build final fn main(): merge guard-rewritten body with module-level inits
	mut main_str := ''
	mut all_main_lines := []string{}
	all_main_lines << comment_lines
	all_main_lines << main_fn_body
	if main_fn_override.len > 0 {
		if all_main_lines.len > 0 {
			// Inject init lines at start of the guard-rewritten fn main() body
			open_brace := main_fn_override.index('{') or { -1 }
			if open_brace >= 0 {
				head := main_fn_override[0..open_brace + 1]
				tail := main_fn_override[open_brace + 1..]
				mut indented := []string{}
				for line in all_main_lines {
					indented << indent(line, 1, '\t')
				}
				main_str = '${head}\n${indented.join('\n')}${tail}'
			} else {
				main_str = main_fn_override
			}
		} else {
			main_str = main_fn_override
		}
	} else if all_main_lines.len > 0 {
		mut indented := []string{}
		for line in all_main_lines {
			indented << indent(line, 1, '\t')
		}
		main_str = 'fn main() {\n${indented.join('\n')}\n}'
	}

	// Assemble output sections in order
	mut parts := []string{}
	if t.has_global_decl {
		parts << '@[translated]'
	}
	parts << 'module ${module_name}'

	if t.usings.len > 0 {
		mut import_lines := []string{}
		for u in t.usings {
			import_lines << 'import ${u}'
		}
		parts << import_lines.join('\n')
	}

	if type_decls.len > 0 {
		parts << type_decls.join('\n\n')
	}
	if struct_decls.len > 0 {
		parts << struct_decls.join('\n\n')
	}
	if func_decls.len > 0 {
		parts << func_decls.join('\n\n')
	}
	if main_str != '' {
		parts << main_str
	}

	return parts.join('\n\n') + '\n'
}

// add_using registers an import usage required by generated code.
pub fn (mut t VTranspiler) add_using(mod string) {
	if mod == '' {
		return
	}
	if mod in t.usings {
		return
	}
	t.usings << mod
}

// new_tmp returns a fresh temporary variable name.
pub fn (mut t VTranspiler) new_tmp(prefix string) string {
	return t.tmp_gen.next(prefix)
}

// indent_code indents `code` by `level` using a tab indent.
pub fn (mut t VTranspiler) indent_code(code string, level int) string {
	// refer to t to avoid v vet "unused receiver" warnings
	_ = t.module_name
	return indent(code, level, '\t')
}

// visit_body_stmts visits a list of statements and returns an indented block string.
pub fn (mut t VTranspiler) visit_body_stmts(stmts []Stmt, level int) string {
	mut parts := []string{}
	for stmt in stmts {
		s := t.visit_stmt(stmt)
		if s.len == 0 {
			continue
		}
		parts << indent(s, level, '\t')
	}
	return parts.join('\n')
}

// visit_return emits V code for a Return statement.
pub fn (mut t VTranspiler) visit_return(node Return) string {
	if val := node.value {
		// A function with an N-tuple return type must return N separate values;
		// returning the V array literal is not a multi-return.
		if t.current_return_count > 0 && (val is Tuple || val is List) {
			elts := if val is Tuple { (val as Tuple).elts } else { (val as List).elts }
			if elts.len == t.current_return_count {
				mut parts := []string{}
				for e in elts {
					parts << t.visit_expr(e)
				}
				return 'return ${parts.join(', ')}'
			}
		}
		return 'return ${t.visit_expr(val)}'
	}
	return 'return'
}

// visit_delete emits V delete operations where V has an equivalent.
pub fn (mut t VTranspiler) visit_delete(node Delete) string {
	mut parts := []string{}
	for target in node.targets {
		parts << t.emit_delete_target(target)
	}
	return parts.join('\n')
}

// emit_delete_target lowers one Python del target into one or more V lines.
fn (mut t VTranspiler) emit_delete_target(target Expr) []string {
	match target {
		Subscript {
			sub := target as Subscript
			if sub.slice is Slice {
				return [
					'// del ${t.visit_expr(target)}  // unsupported: slice deletion',
				]
			}
			base := t.visit_expr(sub.value)
			index := t.visit_expr(sub.slice)
			coll_type := t.infer_expr_type(sub.value)
			if coll_type.starts_with('map[') || sub.value is Dict {
				return ['${base}.delete(${index})']
			}
			if coll_type.starts_with('[]') || coll_type == 'array' || sub.value is List {
				return ['${base}.delete(${index})']
			}
			if coll_type.len > 0 {
				return [
					'// del ${t.visit_expr(target)}  // unsupported: subscript delete on ${coll_type}',
				]
			}
			return [
				'// del ${t.visit_expr(target)}  // unsupported: unknown subscript container',
			]
		}
		Tuple {
			mut lines := []string{}
			for elt in (target as Tuple).elts {
				lines << t.emit_delete_target(elt)
			}
			return lines
		}
		List {
			mut lines := []string{}
			for elt in (target as List).elts {
				lines << t.emit_delete_target(elt)
			}
			return lines
		}
		Name {
			return [
				'// del ${t.visit_expr(target)} - V does not support deleting variables',
			]
		}
		Attribute {
			return [
				'// del ${t.visit_expr(target)}  // unsupported: attribute deletion',
			]
		}
		else {
			return ['// del ${t.visit_expr(target)}  // unsupported del form']
		}
	}
}

// has_setter_decorator returns true if any decorator is a .setter attribute.
fn has_setter_decorator(decorators []main.Expr) bool {
	for d in decorators {
		if d is Attribute {
			if (d as Attribute).attr == 'setter' {
				return true
			}
		}
	}
	return false
}

// visit_stmt visits a statement and dispatches to the appropriate visitor.
pub fn (mut t VTranspiler) visit_stmt(stmt Stmt) string {
	match stmt {
		FunctionDef { return t.visit_function_def_or_closure(stmt) }
		AsyncFunctionDef { return t.visit_async_function_def(stmt) }
		ClassDef { return t.visit_class_def(stmt) }
		Return { return t.visit_return(stmt) }
		Delete { return t.visit_delete(stmt) }
		Assign { return t.visit_assign(stmt) }
		AugAssign { return t.visit_aug_assign(stmt) }
		AnnAssign { return t.visit_ann_assign(stmt) }
		For { return t.visit_for(stmt) }
		AsyncFor { return t.visit_async_for(stmt) }
		While { return t.visit_while(stmt) }
		If { return t.visit_if(stmt) }
		With { return t.visit_with(stmt) }
		AsyncWith { return t.visit_async_with(stmt) }
		Raise { return t.visit_raise(stmt) }
		Try { return t.visit_try(stmt) }
		Assert { return t.visit_assert(stmt) }
		Import { return t.visit_import(stmt) }
		ImportFrom { return t.visit_import_from(stmt) }
		Global { return t.visit_global(stmt) }
		Nonlocal { return t.visit_nonlocal(stmt) }
		ExprStmt { return t.visit_expr_stmt(stmt) }
		Pass { return '// pass' }
		Break { return 'break' }
		Continue { return 'continue' }
		TypeAlias { return t.visit_type_alias(stmt) }
		Match { return t.visit_match(stmt) }
	}
}

// visit_expr visits an expression and dispatches to expression visitors.
pub fn (mut t VTranspiler) visit_expr(expr Expr) string {
	match expr {
		Constant { return t.visit_constant(expr) }
		Name { return t.visit_name(expr) }
		BinOp { return t.visit_binop(expr) }
		UnaryOp { return t.visit_unaryop(expr) }
		BoolOp { return t.visit_boolop(expr) }
		Compare { return t.visit_compare(expr) }
		Call { return t.visit_call(expr) }
		Attribute { return t.visit_attribute(expr) }
		Subscript { return t.visit_subscript(expr) }
		Slice { return t.visit_slice(expr) }
		List { return t.visit_list(expr) }
		Tuple { return t.visit_tuple(expr) }
		Dict { return t.visit_dict(expr) }
		Set { return t.visit_set(expr) }
		IfExp { return t.visit_ifexp(expr) }
		Lambda { return t.visit_lambda(expr) }
		ListComp { return t.visit_list_comp(expr) }
		SetComp { return t.visit_set_comp(expr) }
		DictComp { return t.visit_dict_comp(expr) }
		GeneratorExp { return t.visit_generator_exp(expr) }
		Await { return t.visit_await(expr) }
		Yield { return t.visit_yield(expr) }
		YieldFrom { return t.visit_yield_from(expr) }
		FormattedValue { return t.visit_formatted_value(expr) }
		JoinedStr { return t.visit_joined_str(expr) }
		NamedExpr { return t.visit_named_expr(expr) }
		Starred { return t.visit_starred(expr) }
	}
}

// visit_function_def_or_closure dispatches to an inline closure when the
// function declares nonlocal variables, otherwise hoists it as a normal function.
fn (mut t VTranspiler) visit_function_def_or_closure(node FunctionDef) string {
	mut nl_names := []string{}
	for stmt in node.body {
		if stmt is Nonlocal {
			nl_names << (stmt as Nonlocal).names
		}
	}
	if nl_names.len > 0 {
		return t.visit_closure_from_funcdef(node, nl_names)
	}
	return t.visit_function_def(node)
}

// visit_closure_from_funcdef emits a nested FunctionDef that uses nonlocal
// variables as an inline V closure variable with a mut capture list.
fn (mut t VTranspiler) visit_closure_from_funcdef(node FunctionDef, nl_names []string) string {
	// Collect locally declared names (params + assigned vars) so we know what is "outer"
	mut local_names := map[string]bool{}
	for arg in node.args.args {
		local_names[arg.arg] = true
	}
	// Also collect names assigned inside the closure body
	for stmt in node.body {
		collect_assigned_names(stmt, mut local_names)
	}

	// Collect names referenced in the body that are not local → outer free variables
	mut referenced := map[string]bool{}
	for stmt in node.body {
		collect_referenced_names(stmt, mut referenced)
	}

	// Outer free vars: referenced but not local and not built-in keywords
	mut outer_free := []string{}
	v_builtins := ['true', 'false', 'none', 'println', 'print', 'len', 'cap']
	for name, _ in referenced {
		if name !in local_names && name !in v_builtins && name !in nl_names {
			outer_free << name
		}
	}
	outer_free.sort()

	// Build capture list: nonlocal vars → "mut <name>", outer free vars → "<name>"
	mut captures := []string{}
	for name in nl_names {
		captures << 'mut ${name}'
	}
	for name in outer_free {
		captures << name
	}
	capture_list := captures.join(', ')

	// Build parameter list (skip 'self' for regular nested functions)
	mut params := []string{}
	for arg in node.args.args {
		if arg.arg == 'self' {
			continue
		}
		ptype := t.typename_from_annotation(arg.annotation)
		if ptype != '' {
			params << '${arg.arg} ${ptype}'
		} else {
			params << arg.arg
		}
	}

	// Return type
	mut ret_type := ''
	if ret := node.returns {
		ret_type = v_return_type(t.typename_from_annotation(ret))
	} else if node.v_annotation != '' {
		// Use inferred return type from frontend analysis
		ret_type = map_type(node.v_annotation)
		if ret_type == 'auto' {
			ret_type = 'Any'
			t.generated_code_has_any_type = true
		}
	}
	if ret_type == '' {
		ret_type = 'Any'
		t.generated_code_has_any_type = true
	}

	// Build body (skip nonlocal declarations)
	mut body_lines := []string{}
	for stmt in node.body {
		if stmt is Nonlocal {
			continue
		}
		result := t.visit_stmt(stmt)
		for line in result.split('\n') {
			if line.len > 0 {
				body_lines << '\t${line}'
			}
		}
	}
	body := body_lines.join('\n')

	mut sig := if capture_list.len > 0 {
		'fn [${capture_list}] (${params.join(', ')})'
	} else {
		'fn (${params.join(', ')})'
	}
	if ret_type != '' {
		sig += ' ${ret_type}'
	}
	return '${node.name} := ${sig} {\n${body}\n}'
}

// collect_assigned_names gathers all names assigned at the top level of a statement.
fn collect_assigned_names(stmt Stmt, mut names map[string]bool) {
	match stmt {
		Assign {
			for t in stmt.targets {
				if t is Name {
					names[(t as Name).id] = true
				}
			}
		}
		AnnAssign {
			if stmt.target is Name {
				names[(stmt.target as Name).id] = true
			}
		}
		For {
			if stmt.target is Name {
				names[(stmt.target as Name).id] = true
			}
		}
		else {}
	}
}

// collect_referenced_names gathers all Name ids referenced in a statement tree.
fn collect_referenced_names(stmt Stmt, mut names map[string]bool) {
	match stmt {
		Assign {
			collect_expr_names(stmt.value, mut names)
		}
		AugAssign {
			collect_expr_names(stmt.value, mut names)
			collect_expr_names(stmt.target, mut names)
		}
		Return {
			if val := stmt.value {
				collect_expr_names(val, mut names)
			}
		}
		ExprStmt {
			collect_expr_names(stmt.value, mut names)
		}
		If {
			collect_expr_names(stmt.test, mut names)
			for s in stmt.body {
				collect_referenced_names(s, mut names)
			}
			for s in stmt.orelse {
				collect_referenced_names(s, mut names)
			}
		}
		While {
			collect_expr_names(stmt.test, mut names)
			for s in stmt.body {
				collect_referenced_names(s, mut names)
			}
		}
		else {}
	}
}

// collect_expr_names gathers all Name ids referenced in an expression tree.
fn collect_expr_names(expr Expr, mut names map[string]bool) {
	match expr {
		Name {
			names[expr.id] = true
		}
		BinOp {
			collect_expr_names(expr.left, mut names)
			collect_expr_names(expr.right, mut names)
		}
		Call {
			collect_expr_names(expr.func, mut names)
			for a in expr.args {
				collect_expr_names(a, mut names)
			}
		}
		Attribute {
			collect_expr_names(expr.value, mut names)
		}
		Subscript {
			collect_expr_names(expr.value, mut names)
			collect_expr_names(expr.slice, mut names)
		}
		UnaryOp {
			collect_expr_names(expr.operand, mut names)
		}
		else {}
	}
}

// visit_function_def emits V code for a Python FunctionDef node.
pub fn (mut t VTranspiler) visit_function_def(node FunctionDef) string {
	// Pre-pass: a local that receives a `mut self` method call must itself be
	// declared `mut`, and that has to be known before the body is emitted.
	{
		// Seed the type of `x = Klass(...)` before scanning for mut receivers.
		for st in node.body {
			if st is Assign {
				a := st as Assign
				if a.targets.len == 1 && a.targets[0] is Name && a.value is Call {
					call := a.value as Call
					cls := t.constructor_name(call)
					if cls != '' {
						t.var_types[(a.targets[0] as Name).id] = cls
					}
				}
			}
		}
		for recv, _ in t.collect_mut_receivers(node.body) {
			t.extra_mut_vars[recv] = true
		}
	}

	// Save var_types and escaped_identifiers for function scope (keep globals, reset locals)
	saved_var_types := t.var_types.clone()
	saved_escaped_identifiers := t.escaped_identifiers.clone()
	t.escaped_identifiers = map[string]bool{}
	saved_current_class := t.current_class_name
	if node.is_class_method {
		t.current_class_name = node.class_name
	}
	// Keep global variable types, reset function-local ones
	mut func_var_types := map[string]string{}
	for k, v in t.var_types {
		if t.global_vars[k] or { false } {
			func_var_types[k] = v
		}
	}
	t.var_types = func_var_types.clone()

	mut signature := []string{}
	// Cross-module symbols need a `pub` visibility in V; single-file output
	// does not. `emit_pub` is set when translating a project rather than a
	// single script.
	if t.emit_pub && node.name != 'main' {
		signature << 'pub fn'
	} else {
		signature << 'fn'
	}

	// Determine emitted function name (dunder → V operator name, or decorated name)
	mut emit_name := node.name
	mut dunder_comment := ''
	if node.dunder_op != '' {
		match node.dunder_op {
			'str', 'len', 'index', 'index_set', 'contains' { emit_name = node.dunder_op }
			else { emit_name = node.dunder_op }
		}
	} else if v_name := python_dunder_method_names[node.name] {
		emit_name = v_name
	} else {
		emit_name = escape_leading_underscore(node.name)
	}
	// @classmethod / @staticmethod: emit as free function named ClassName_funcname
	if node.is_class_method && node.decorator_kind in ['classmethod', 'staticmethod'] {
		emit_name = '${emitted_class_name(node.class_name)}_${node.name}'
		dunder_comment = '// @${node.decorator_kind}\n'
	}

	// Binary/comparison operator overloads need value receivers in V, and V
	// requires both operands of an operator to have the same type.
	is_binop_dunder := node.dunder_op in ['+', '-', '*', '/', '%', '==', '!=', '<', '<=', '>',
		'>=']
	mut emitted_receiver_type := emitted_class_name(node.class_name)
	if tp := t.class_type_params[node.class_name] {
		if tp.len > 0 {
			emitted_receiver_type = '${emitted_receiver_type}[${tp.join(', ')}]'
		}
	}

	// Handle class method receiver (skip for staticmethod / classmethod)
	if node.is_class_method && node.decorator_kind !in ['staticmethod', 'classmethod'] {
		base_receiver := emitted_class_name(node.class_name)
		// Append generic type params if the class is generic (e.g. Stack[T])
		mut emitted_receiver := base_receiver
		if tp := t.class_type_params[node.class_name] {
			if tp.len > 0 {
				emitted_receiver = '${base_receiver}[${tp.join(', ')}]'
			}
		}
		mut use_mut_recv := !is_binop_dunder && ('self' in node.mutable_vars || node.name == '__init__')
		// A method that calls `super().m()` on a base with a `mut self` receiver
		// mutates the embedded value, so it needs `mut self` here as well.
		if !use_mut_recv && node.is_class_method {
			mut v_name := node.dunder_op
			if v_name == '' {
				v_name = python_dunder_method_names[node.name] or { node.name }
			}
			if t.mut_receiver_methods['${node.class_name}_${v_name}'] {
				use_mut_recv = true
			}
		}
		if use_mut_recv {
			signature << '(mut self ${emitted_receiver})'
		} else {
			signature << '(self ${emitted_receiver})'
		}
	}

	// Process arguments
	mut args_strs := []string{}
	mut generics := []string{}
	mut mut_indices := []int{} // Track which parameter indices are mutable
	mut param_idx := 0

	for arg in node.args.args {
		if arg.arg == 'self' {
			continue
		}
		// Skip `cls` for @classmethod
		if arg.arg == 'cls' && node.decorator_kind == 'classmethod' {
			continue
		}

		mut typename := ''
		if ann := arg.annotation {
			typename = t.typename_from_annotation(ann)
		}

		// Python commonly leaves the operand of a comparison unannotated, which
		// would otherwise become `Any`; V needs the receiver type there.
		if typename == '' && is_binop_dunder && node.is_class_method {
			typename = emitted_receiver_type
		}

		mut arg_name := escape_identifier(arg.arg)
		// Track identifiers escaped due to built-in type name conflicts
		if arg.arg in v_builtin_types {
			t.escaped_identifiers[arg.arg] = true
		}
		// Check if this argument is mutable
		if arg.arg in node.mutable_vars {
			arg_name = 'mut ${arg_name}'
			mut_indices << param_idx
		}

		if typename == '' {
			// V functions require explicit parameter types.
			typename = 'Any'
			t.generated_code_has_any_type = true
		} else if typename.len == 1 && typename[0] >= `A` && typename[0] <= `Z` {
			// Single uppercase letter is a generic
			if typename !in generics {
				generics << typename
			}
		}

		args_strs << '${arg_name} ${typename}'
		// Track parameter type for return type inference
		if typename.len > 0 && typename != 'Any' && !(typename.len == 1 && typename[0] >= `A`
			&& typename[0] <= `Z`) {
			t.var_types[arg.arg] = typename
		}
		param_idx++
	}

	// Python keyword-only args come after `*args`, but V requires the variadic
	// parameter to be last, so emit them here, before it.
	for i, kwonly in node.args.kwonlyargs {
		kwname := escape_identifier(kwonly.arg)
		mut kwtype := 'Any'
		t.generated_code_has_any_type = true
		if ann := kwonly.annotation {
			kwtype = t.typename_from_annotation(ann)
		}
		// V has no default parameter values; defaults are filled in at call
		// sites via func_defaults instead.
		args_strs << '${kwname} ${kwtype}'
	}

	// Register function's mut parameter indices for call-site mut keyword generation
	if mut_indices.len > 0 && !node.is_class_method {
		t.mut_param_indices[node.name] = mut_indices
	}

	// Record default values for call-site default filling
	if node.args.defaults.len > 0 && !node.is_class_method {
		mut default_strs := []string{}
		for def in node.args.defaults {
			default_strs << t.visit_expr(def)
		}
		t.func_defaults[node.name] = default_strs
		t.func_param_count[node.name] = param_idx
	}

	// **kwargs has to precede *args: V requires the variadic parameter to be
	// last, so a signature with both cannot put kwargs after it.
	if kwarg := node.args.kwarg {
		t.generated_code_has_any_type = true
		args_strs << '${escape_identifier(kwarg.arg)} map[string]Any // **kwargs'
	}

	// Handle vararg (*args)
	if vararg := node.args.vararg {
		mut typename := ''
		if ann := vararg.annotation {
			typename = t.typename_from_annotation(ann)
		}
		if typename.starts_with('[]') {
			typename = '...' + typename[2..]
		} else if typename == '' {
			typename = '...Any'
			t.generated_code_has_any_type = true
		} else {
			typename = '...' + typename
		}
		args_strs << '${escape_identifier(vararg.arg)} ${typename}'
	}

	// For generator functions, add channel parameter
	if node.is_generator {
		yield_type := t.infer_generator_yield_type(node.body)
		args_strs << 'ch chan ${yield_type}'
	}

	signature << '${emit_name}(${args_strs.join(', ')})'

	// Pre-scan body to populate var_types for return type inference
	// (no-op in current backend)
	_ = node.body

	// Return type
	saved_return_count := t.current_return_count
	t.current_return_count = 0
	if !node.is_void && !node.is_generator && node.name != '__init__' {
		if ret := node.returns {
			ret_type := v_return_type(t.typename_from_annotation(ret))
			if ret_type.starts_with('(') {
				t.current_return_count = ret_type.count(',') + 1
			}
			signature << ret_type
			t.func_return_types[node.name] = ret_type
		} else if node.v_annotation != '' {
			// Use inferred return type from frontend analysis
			mut ret_type := map_type(node.v_annotation)
			if ret_type == 'auto' {
				ret_type = 'Any'
				t.generated_code_has_any_type = true
			}
			signature << ret_type
			t.func_return_types[node.name] = ret_type
		} else {
			// Fallback to Any if no type information available
			inferred := 'Any'
			t.generated_code_has_any_type = true
			signature << inferred
			t.func_return_types[node.name] = inferred
		}
	}

	// Process body - separate nested function definitions
	mut nested_fndefs := []string{}
	mut body_stmts := []Stmt{}
	mut first_stmt := true
	for stmt in node.body {
		// Skip docstrings (first statement that is a bare string constant)
		if first_stmt {
			first_stmt = false
			if stmt is ExprStmt {
				es := stmt as ExprStmt
				if es.value is Constant {
					c := es.value as Constant
					if c.value is string {
						continue
					}
				}
			}
		}
		match stmt {
			FunctionDef {
				// Collect nonlocal names declared inside this nested function.
				mut nl_names := []string{}
				for inner_stmt in stmt.body {
					if inner_stmt is Nonlocal {
						nl_names << (inner_stmt as Nonlocal).names
					}
				}
				if nl_names.len > 0 {
					// Emit as an inline closure variable with a mut capture list.
					body_stmts << Stmt(stmt)
				} else {
					nested_fndefs << t.visit_function_def(stmt)
				}
			}
			AsyncFunctionDef {
				nested_fndefs << t.visit_async_function_def(stmt)
			}
			else {
				body_stmts << stmt
			}
		}
	}

	// Pre-scan body for variables passed to mut-parameter functions
	t.prescan_mut_call_args(body_stmts)

	// Build body
	mut body_lines := []string{}
	if node.is_generator {
		body_lines << t.indent_code('defer { ch.close() }', 1)
	}
	body_lines << t.visit_body_stmts(body_stmts, 1)
	body := body_lines.join('\n')

	func_code := '${dunder_comment}${signature.join(' ')} {\n${body}\n}'

	// Emit comments for unsupported decorators (@functools.wraps, @lru_cache, etc.)
	mut decorator_comments := []string{}
	for d in node.decorator_list {
		dname := match d {
			Name {
				(d as Name).id
			}
			Attribute {
				(d as Attribute).attr
			}
			Call {
				cf := (d as Call).func
				match cf {
					Name { (cf as Name).id }
					Attribute { (cf as Attribute).attr }
					else { '' }
				}
			}
			else {
				''
			}
		}

		unsupported := ['wraps', 'lru_cache', 'cache', 'cached_property', 'total_ordering',
			'singledispatch', 'contextmanager']
		if dname in unsupported {
			decorator_comments << '// @${dname}: unsupported decorator — remove or implement manually'
		}
	}

	// Prepend any pending type-hint notes (e.g. Union hints) as comments
	mut notes_prefix := ''
	if t.pending_type_notes.len > 0 {
		notes_prefix = t.pending_type_notes.join('\n') + '\n'
		t.pending_type_notes = []string{}
	}

	// Restore var_types and escaped_identifiers from parent scope
	t.var_types = saved_var_types.clone()
	t.escaped_identifiers = saved_escaped_identifiers.clone()

	// A nested function must not inherit the enclosing function's return arity.
	t.current_return_count = saved_return_count
	if nested_fndefs.len > 0 {
		t.current_class_name = saved_current_class
		return nested_fndefs.join('\n') + '\n' + notes_prefix + decorator_comments.join('\n') + if decorator_comments.len > 0 {
			'\n'
		} else {
			''
		} + func_code
	}
	t.current_class_name = saved_current_class
	return notes_prefix + decorator_comments.join('\n') + if decorator_comments.len > 0 {
		'\n'
	} else {
		''
	} + func_code
}

// visit_async_function_def emits V code for an AsyncFunctionDef node (converted to sync).
pub fn (mut t VTranspiler) visit_async_function_def(node AsyncFunctionDef) string {
	// Convert to regular FunctionDef
	fd := FunctionDef{
		name:            node.name
		args:            node.args
		body:            node.body
		decorator_list:  node.decorator_list
		returns:         node.returns
		type_comment:    node.type_comment
		loc:             node.loc
		is_generator:    node.is_generator
		is_void:         node.is_void
		mutable_vars:    node.mutable_vars
		is_class_method: node.is_class_method
		class_name:      node.class_name
		decorator_kind:  node.decorator_kind
		dunder_op:       node.dunder_op
	}
	return t.visit_function_def(fd)
}

// visit_protocol_class emits a V interface for a Python Protocol class.
fn (mut t VTranspiler) visit_protocol_class(node ClassDef, emitted_name string) string {
	t.known_classes[node.name] = []string{}
	mut methods := []string{}
	for stmt in node.body {
		if stmt is FunctionDef {
			fd := stmt as FunctionDef
			if fd.name == '__init__' {
				continue
			}
			// Build interface method signature (no body)
			mut args_strs := []string{}
			for arg in fd.args.args {
				if arg.arg == 'self' {
					continue
				}
				mut typename := 'Any'
				t.generated_code_has_any_type = true
				if ann := arg.annotation {
					typename = t.typename_from_annotation(ann)
					if typename == '' {
						typename = 'Any'
					}
				}
				args_strs << '${escape_identifier(arg.arg)} ${typename}'
			}
			mut ret_type := ''
			if !fd.is_void {
				if ret := fd.returns {
					ret_type = t.typename_from_annotation(ret)
				}
			}
			sig := if ret_type.len > 0 {
				'\t${fd.name}(${args_strs.join(', ')}) ${ret_type}'
			} else {
				'\t${fd.name}(${args_strs.join(', ')})'
			}
			methods << sig
		}
	}
	if methods.len > 0 {
		return 'interface ${emitted_name} {\n${methods.join('\n')}\n}'
	}
	return 'interface ${emitted_name} {}'
}

// visit_class_def emits V code for a ClassDef node.
pub fn (mut t VTranspiler) visit_class_def(node ClassDef) string {
	emitted_name := emitted_class_name(node.name)

	// Protocol → V interface
	if node.is_protocol {
		return t.visit_protocol_class(node, emitted_name)
	}

	// Detect @dataclass decorator — changes field emission strategy
	mut is_dataclass := false
	for d in node.decorator_list {
		if d is Name && (d as Name).id == 'dataclass' {
			is_dataclass = true
			break
		}
		if d is Attribute && (d as Attribute).attr == 'dataclass' {
			is_dataclass = true
			break
		}
		if d is Call {
			fn_part := (d as Call).func
			if fn_part is Name && (fn_part as Name).id == 'dataclass' {
				is_dataclass = true
				break
			}
		}
	}
	_ = is_dataclass // used below for field-default emission
	mut fields := []string{}
	mut field_names := []string{}
	mut base_names := []string{}
	mut class_attr_values := []string{}
	mut class_attr_syms := map[string]string{}
	mut init_field_names := map[string]bool{}

	for stmt in node.body {
		match stmt {
			FunctionDef {
				if stmt.name != '__init__' {
					continue
				}
				for init_stmt in stmt.body {
					match init_stmt {
						Assign {
							if init_stmt.targets.len == 1 && init_stmt.targets[0] is Attribute {
								attr := init_stmt.targets[0] as Attribute
								if attr.value is Name && (attr.value as Name).id == 'self' {
									init_field_names[attr.attr] = true
								}
							}
						}
						AnnAssign {
							if init_stmt.target is Attribute {
								attr := init_stmt.target as Attribute
								if attr.value is Name && (attr.value as Name).id == 'self' {
									init_field_names[attr.attr] = true
								}
							}
						}
						else {}
					}
				}
			}
			Assign {
				if stmt.targets.len == 1 && stmt.targets[0] is Name {
					attr_name := (stmt.targets[0] as Name).id
					if !is_v_field_ident(attr_name) {
						class_attr_syms[attr_name] = class_attr_symbol_name(node.name, attr_name)
					}
				}
			}
			else {}
		}
	}
	t.class_attr_symbols[node.name] = class_attr_syms.clone()

	for stmt in node.body {
		match stmt {
			Assign {
				if stmt.targets.len == 1 && stmt.targets[0] is Name {
					attr_name := (stmt.targets[0] as Name).id
					if sym := class_attr_syms[attr_name] {
						class_attr_values << 'const ${sym} = ${t.visit_expr(stmt.value)}'
					}
				}
			}
			else {}
		}
	}

	// Map each Python field name to its V spelling so attribute access agrees
	// with the struct declaration.
	//
	// V has one namespace per struct for fields and methods, while Python keeps
	// `self._celsius` and a `@property celsius` distinct. Escaping the leading
	// underscore can therefore collide with a method name, so a collision keeps
	// an extra trailing underscore.
	mut method_names := map[string]bool{}
	for stmt in node.body {
		if stmt is FunctionDef {
			mut v_name := (stmt as FunctionDef).dunder_op
			if v_name == '' {
				v_name = python_dunder_method_names[(stmt as FunctionDef).name] or {
					(stmt as FunctionDef).name
				}
			}
			if (stmt as FunctionDef).decorator_kind == 'setter' {
				v_name = 'set_${v_name}'
			}
			method_names[v_name] = true
		}
	}
	mut field_escapes := map[string]string{}
	for decl, _ in node.declarations {
		if decl in python_dunder_class_attrs {
			continue
		}
		mut escaped := escape_leading_underscore(decl)
		if escaped != decl && escaped in method_names {
			escaped += '_'
		}
		field_escapes[decl] = escaped
	}
	t.class_field_escapes[node.name] = field_escapes.clone()

	if node.declarations.len > 0 {
		mut has_typed_fields := false
		for decl, typename in node.declarations {
			// Python bookkeeping attributes (__slots__ and friends) have no V
			// counterpart; emitting them as fields is always wrong.
			if decl in python_dunder_class_attrs {
				continue
			}
			if decl in class_attr_syms && decl !in init_field_names {
				continue
			}
			mut field_name := field_escapes[decl] or { decl }
			mut decl_type := typename
			if decl_type == '' {
				// Preserve untyped __init__ fields so method assignments compile.
				decl_type = 'Any'
				t.generated_code_has_any_type = true
			}
			if !has_typed_fields {
				fields << 'pub mut:'
				has_typed_fields = true
			}
			mut typ := map_type(decl_type)
			if typ == 'auto' {
				typ = 'Any'
				t.generated_code_has_any_type = true
			}
			if should_emit_ref_field_type(typ) {
				typ = '&${typ}'
			}
			if default_expr := node.class_defaults[decl] {
				default_str := t.visit_expr(default_expr)
				fields << t.indent_code('${field_name} ${typ} = ${default_str}', 1)
			} else {
				fields << t.indent_code('${field_name} ${typ}', 1)
			}
			field_names << field_name
		}
	}
	for base in node.bases {
		if base is Name {
			base_name := (base as Name).id
			if base_name.len > 0 {
				base_names << base_name
			}
		}
	}
	// Register class shape metadata for constructor generation
	t.class_direct_fields[node.name] = field_names
	t.class_base_names[node.name] = base_names
	mut all_field_names := []string{}
	for base_name in base_names {
		base_fields := t.known_classes[base_name] or { []string{} }
		all_field_names << base_fields
	}
	all_field_names << field_names
	t.known_classes[node.name] = all_field_names
	if node.type_params.len > 0 {
		t.class_type_params[node.name] = node.type_params
	}

	// Embed base classes (inheritance -> struct embedding)
	mut embeds := []string{}
	for base_name in base_names {
		if base_name in t.known_classes {
			embeds << t.indent_code(emitted_class_name(base_name), 1)
		}
	}

	mut all_parts := []string{}
	all_parts << embeds
	all_parts << fields

	mut struct_def := if all_parts.len > 0 {
		if node.type_params.len > 0 {
			tp := node.type_params.join(', ')
			'pub struct ${emitted_name}[${tp}] {\n${all_parts.join('\n')}\n}'
		} else {
			'pub struct ${emitted_name} {\n${all_parts.join('\n')}\n}'
		}
	} else {
		if node.type_params.len > 0 {
			tp := node.type_params.join(', ')
			'pub struct ${emitted_name}[${tp}] {\n}'
		} else {
			'pub struct ${emitted_name} {\n}'
		}
	}

	// Add class docstring as struct comment (V convention: "// StructName ...")
	if doc := node.docstring_comment {
		lines := doc.split('\n')
		mut comment_lines := []string{}
		for i, raw_line in lines {
			line := raw_line.trim_space()
			if line.len == 0 {
				if i > 0 && i < lines.len - 1 {
					comment_lines << '//'
				}
				continue
			}
			if i == 0 && !line.starts_with(node.name) {
				comment_lines << '// ${node.name} - ${line}'
			} else {
				comment_lines << '// ${line}'
			}
		}
		if comment_lines.len > 0 {
			struct_def = comment_lines.join('\n') + '\n' + struct_def
		}
	}

	// Emit class-level attributes as module-level symbols.
	if class_attr_values.len > 0 {
		struct_def = class_attr_values.join('\n') + '\n\n' + struct_def
	}

	// Pre-pass: register return types of all methods that have explicit annotations
	for stmt in node.body {
		if stmt is FunctionDef {
			if !stmt.is_void {
				if ret := stmt.returns {
					ret_type := t.typename_from_annotation(ret)
					if ret_type.len > 0 {
						t.func_return_types[stmt.name] = ret_type
					}
				}
			}
		}
	}

	// Pre-pass: record which methods need a `mut self` receiver, so that calls
	// through an embedded base (`self.Base.method(...)` from `super()`) can mark
	// the embedded value as mutable.
	base_name_early := t.class_base_names[node.name] or { []string{} }
	base_key := if base_name_early.len > 0 { emitted_class_name(base_name_early[0]) } else { '' }
	for stmt in node.body {
		if stmt is FunctionDef {
			is_binop := stmt.dunder_op in ['+', '-', '*', '/', '%', '==', '!=', '<', '<=', '>',
				'>=']
			mut needs_mut := !is_binop && ('self' in stmt.mutable_vars || stmt.name == '__init__')
			// A `super().method()` call reaches an embedded base value, so this
			// method needs a `mut self` receiver whenever the base method does.
			if !needs_mut && base_key != '' {
				for called in collect_super_calls(stmt.body) {
					v_called := python_dunder_method_names[called] or { called }
					if t.mut_receiver_methods['${base_key}_${v_called}'] {
						needs_mut = true
						break
					}
				}
			}
			if needs_mut {
				mut v_name := stmt.dunder_op
				if v_name == '' {
					v_name = python_dunder_method_names[stmt.name] or { stmt.name }
				}
				t.mut_receiver_methods['${node.name}_${v_name}'] = true
			}
		}
	}

	// Process body (methods)
	mut methods := []string{}
	mut static_fns := []string{}
	for stmt in node.body {
		match stmt {
			FunctionDef {
				// Mark as class method
				mut fd := stmt
				fd.is_class_method = true
				fd.class_name = node.name
				// Rename @property.setter methods to set_<name> to avoid duplicate method names
				if has_setter_decorator(fd.decorator_list) {
					fd.name = 'set_${fd.name}'
				}
				emitted := t.visit_function_def(fd)
				if fd.decorator_kind in ['staticmethod', 'classmethod'] {
					static_fns << emitted
				} else {
					methods << emitted
				}
			}
			else {}
		}
	}

	mut result := struct_def
	if methods.len > 0 {
		result += '\n\n' + methods.join('\n\n')
	}
	if static_fns.len > 0 {
		result += '\n\n' + static_fns.join('\n\n')
	}
	return result
}

// visit_assign emits V code for an Assign statement.
pub fn (mut t VTranspiler) visit_assign(node Assign) string {
	// Literal[v1, v2, ...] assignment — emit a const block or enum as documentation.
	if node.is_typevar_assign && node.literal_values.len > 0 {
		name := escape_identifier(node.literal_name.to_lower())
		// Detect kind: all ints → enum, otherwise const strings
		mut all_ints := true
		for v in node.literal_values {
			// values arrive as JSON strings; check if they look like integers
			trimmed := v.trim_space()
			is_int := trimmed.len > 0
				&& (trimmed[0].is_digit() || (trimmed[0] == `-` && trimmed.len > 1))
				&& trimmed[1..].bytes().all(it.is_digit())
			if !is_int {
				all_ints = false
				break
			}
		}
		if all_ints {
			mut lines := ['enum ${node.literal_name} {']
			for v in node.literal_values {
				lines << '\t${name}_${v} = ${v}'
			}
			lines << '}'
			return lines.join('\n')
		} else {
			// String / mixed literals — emit a const block
			mut lines := ['const (']
			for v in node.literal_values {
				vident := escape_identifier(v.to_lower().replace(' ', '_').replace('-', '_'))
				lines << "\t${name}_${vident} = '${v}'"
			}
			lines << ')'
			return lines.join('\n')
		}
	}
	// Skip other TypeVar assignments — they are Python type-system metadata.
	if node.is_typevar_assign {
		return ''
	}
	// Record the type of `x = Klass(...)` so a later `x.method()` call can see
	// whether that method needs a `mut` receiver.
	if node.targets.len == 1 && node.targets[0] is Name && node.value is Call {
		call := node.value as Call
		cls := t.constructor_name(call)
		if cls != '' {
			t.var_types[(node.targets[0] as Name).id] = cls
		}
	}
	// Track variables assigned from Path(...) constructor so path-property
	// attributes (.name, .parent, .stem, .suffix) can be translated correctly.
	if node.targets.len == 1 && node.targets[0] is Name {
		tname := (node.targets[0] as Name).id
		if node.value is Call {
			call := node.value as Call
			if call.func is Name {
				fname := (call.func as Name).id
				match fname {
					'Path' {
						t.path_vars[tname] = true
					}
					'namedtuple' {
						// TODO: restore full namedtuple lowering.
						_ = call
						return ''
					}
					'defaultdict' {
						// defaultdict(int) → map[string]int{}
						val_type := if call.args.len > 0 {
							t.typename_from_annotation(call.args[0])
						} else {
							t.generated_code_has_any_type = true
							'Any'
						}
						return '${tname} := map[string]${val_type}{}'
					}
					'Counter' {
						// Counter(iterable) → build map[string]int from counts
						if call.args.len > 0 {
							iter := t.visit_expr(call.args[0])
							return '${tname} := (fn (items []string) map[string]int {\n\tmut m := map[string]int{}\n\tfor item in items { m[item]++ }\n\treturn m\n})(${iter})'
						}
						return '${tname} := map[string]int{}'
					}
					'deque' {
						// deque(list) → []Any (V arrays support append/prepend)
						t.generated_code_has_any_type = true
						if call.args.len > 0 {
							inner := t.visit_expr(call.args[0])
							return 'mut ${tname} := []Any(${inner})'
						}
						return 'mut ${tname} := []Any{}'
					}
					'OrderedDict' {
						// OrderedDict() → map[string]Any{} (V maps are insertion-ordered)
						t.generated_code_has_any_type = true
						return 'mut ${tname} := map[string]Any{}'
					}
					else {}
				}
			}
		}
	}
	// Special-case __all__ exception exports into a V union alias.
	if node.targets.len == 1 && node.targets[0] is Name {
		target_name := (node.targets[0] as Name).id
		if target_name == '__all__' && node.value is List {
			mut members := []string{}
			for elt in (node.value as List).elts {
				if elt is Constant {
					c := elt as Constant
					if c.value is string {
						name := c.value as string
						if name.ends_with('Exception') {
							members << name
						}
					}
				}
			}
			if members.len > 0 {
				return 'type WebDriverExceptions = ${members.join(' | ')}'
			}
			return ''
		}
	}

	// Track variable types for print() optimization
	for target in node.targets {
		if target is Name {
			n := target as Name
			inferred := t.infer_expr_type(node.value)
			if inferred.len > 0 {
				t.var_types[n.id] = inferred
			}
		}
	}

	mut assigns := []string{}
	use_temp := node.targets.len > 1 && node.value is Call

	// Determine if RHS was an ellipsis so we can append a trailing
	// comment at the end of the generated assignment line(s).
	mut trailing_comment := ''
	if node.value is Constant {
		c := node.value as Constant
		if c.value is EllipsisValue {
			trailing_comment = ' // ...'
		}
	}

	if use_temp {
		assigns << 'mut tmp := ${t.visit_expr(node.value)}'
	}

	for target in node.targets {
		mut is_redefined := false
		if target is Name {
			n := target as Name
			is_redefined = n.id in node.redefined_targets || (t.global_vars[n.id] or { false })
		}

		value_str := if use_temp { 'tmp' } else { t.visit_expr(node.value) }

		match target {
			Tuple {
				// Tuple unpacking
				elts := target.elts

				// Check for starred unpacking
				has_starred := elts.any(fn (e Expr) bool {
					return e is Starred
				})

				if has_starred {
					assigns << t.handle_starred_unpack(elts, value_str)
				} else {
					// Check if value is a tuple/list literal with same length - can unpack directly
					is_tuple_swap := node.value is Tuple
						&& (node.value as Tuple).elts.len == elts.len

					if is_tuple_swap {
						// Direct tuple swap: x, y = y, x or a, b, c = 1, 2, 3
						mut subtargets := []string{}
						mut any_redefined := false
						mut all_names_mutable := true
						mut has_subscript_or_attr := false

						// Check if all targets are mutable names (meaning they were defined earlier)
						for st in elts {
							if st is Name {
								if st.id in node.redefined_targets {
									any_redefined = true
								}
								if !st.is_mutable {
									all_names_mutable = false
								}
							} else if st is Subscript || st is Attribute {
								has_subscript_or_attr = true
							} else {
								all_names_mutable = false
							}
						}

						// If all names are marked mutable, this is likely a reassignment (like swap)
						// Use = without mut prefix
						for st in elts {
							mut subkw := ''
							if st is Name {
								if !any_redefined && !all_names_mutable && !has_subscript_or_attr {
									if st.is_mutable && st.id !in node.redefined_targets {
										subkw = 'mut '
									}
								}
							}
							subtargets << '${subkw}${t.visit_expr(st)}'
						}

						// Check if any target is _ (discard) - V uses = for those
						has_discard := elts.any(fn (e Expr) bool {
							if e is Name {
								return (e as Name).id == '_'
							}
							return false
						})
						op := if is_redefined || any_redefined || all_names_mutable
							|| has_subscript_or_attr || has_discard {
							'='
						} else {
							':='
						}
						// Strip brackets from value
						mut val := value_str
						if val.starts_with('[') && val.ends_with(']') {
							val = val[1..val.len - 1]
						}
						assigns << '${subtargets.join(', ')} ${op} ${val}'
					} else {
						// Unpacking from array/variable - V doesn't support this directly
						// Generate individual assignments: a := arr[0]; b := arr[1]; c := arr[2]
						tmp_var := t.new_tmp('unpack')
						assigns << '${tmp_var} := ${value_str}'
						for i, st in elts {
							mut any_redefined := false
							if st is Name {
								if st.id in node.redefined_targets {
									any_redefined = true
								}
							}
							op := if any_redefined { '=' } else { ':=' }
							// Array elements need mut for V, but a discard target
							// must stay bare: V rejects `mut _`.
							lhs := t.visit_expr(st)
							mut subkw := ''
							if !any_redefined && lhs.trim_space() != '_' {
								subkw = 'mut '
							}
							assigns << '${subkw}${lhs} ${op} ${tmp_var}[${i}]'
						}
					}
				}
			}
			List {
				// List unpacking
				elts := target.elts

				// Check for starred unpacking
				has_starred := elts.any(fn (e Expr) bool {
					return e is Starred
				})

				if has_starred {
					assigns << t.handle_starred_unpack(elts, value_str)
				} else {
					// Check if value is a list/tuple literal with same length
					is_list_literal :=
						(node.value is List && (node.value as List).elts.len == elts.len)
							|| (node.value is Tuple && (node.value as Tuple).elts.len == elts.len)

					if is_list_literal {
						mut subtargets := []string{}
						mut any_redefined := false
						for st in elts {
							mut subkw := ''
							if st is Name {
								if st.is_mutable && st.id !in node.redefined_targets {
									subkw = 'mut '
								}
								if st.id in node.redefined_targets {
									any_redefined = true
								}
							}
							subtargets << '${subkw}${t.visit_expr(st)}'
						}
						op := if is_redefined || any_redefined { '=' } else { ':=' }
						mut val := value_str
						if val.starts_with('[') && val.ends_with(']') {
							val = val[1..val.len - 1]
						}
						assigns << '${subtargets.join(', ')} ${op} ${val}'
					} else {
						// Unpacking from array/variable - generate individual assignments
						tmp_var := t.new_tmp('unpack')
						assigns << '${tmp_var} := ${value_str}'
						for i, st in elts {
							mut subkw := ''
							mut any_redefined := false
							if st is Name {
								if st.is_mutable && st.id !in node.redefined_targets {
									subkw = 'mut '
								}
								if st.id in node.redefined_targets {
									any_redefined = true
								}
							}
							op := if any_redefined { '=' } else { ':=' }
							assigns << '${subkw}${t.visit_expr(st)} ${op} ${tmp_var}[${i}]'
						}
					}
				}
			}
			Subscript, Attribute {
				assigns << '${t.visit_expr(target)} = ${value_str}'
			}
			Name {
				needs_mut := target.is_mutable || (t.extra_mut_vars[target.id] or { false })
				kw := if needs_mut && !is_redefined { 'mut ' } else { '' }
				op := if is_redefined { '=' } else { ':=' }
				assigns << '${kw}${t.visit_expr(target)} ${op} ${value_str}'
			}
			else {
				assigns << '${t.visit_expr(target)} := ${value_str}'
			}
		}
	}

	// If we need to attach a trailing comment to indicate the original
	// Python ellipsis, append it to the final generated assignment line(s).
	// (the last element) so it appears at end-of-line and does not
	// interfere with any earlier temporary initializers.
	if trailing_comment != '' && assigns.len > 0 {
		assigns[assigns.len - 1] = '${assigns[assigns.len - 1]}${trailing_comment}'
	}

	return assigns.join('\n')
}

// handle_starred_unpack handles starred unpacking in assignments
fn (mut t VTranspiler) handle_starred_unpack(elts []main.Expr, value_str string) string {
	mut starred_idx := -1
	for i, e in elts {
		if e is Starred {
			starred_idx = i
			break
		}
	}

	tmp_var := t.new_tmp('unpack')
	mut assigns := []string{}
	assigns << '${tmp_var} := ${value_str}'

	for i, elt in elts {
		mut target_elt := elt
		mut idx_val := ''

		if i < starred_idx {
			idx_val = '${tmp_var}[${i}]'
		} else if i == starred_idx {
			end := elts.len - 1 - i
			if end > 0 {
				idx_val = '${tmp_var}[${i}..${tmp_var}.len - ${end}]'
			} else {
				idx_val = '${tmp_var}[${i}..]'
			}
			if elt is Starred {
				target_elt = (elt as Starred).value
			}
		} else {
			dist := elts.len - 1 - i
			if dist == 0 {
				idx_val = '${tmp_var}.last()'
			} else {
				idx_val = '${tmp_var}[${tmp_var}.len - ${dist + 1}]'
			}
		}

		// Array elements need mut for V slice assignment, but a discard target
		// (`_`) must stay bare: V rejects `mut _`.
		mut lhs := t.visit_expr(target_elt)
		if lhs.trim_space() != '_' {
			lhs = 'mut ${lhs}'
		}
		assigns << '${lhs} := ${idx_val}'
	}

	return assigns.join('\n')
}

// visit_aug_assign emits V code for an AugAssign statement.
pub fn (mut t VTranspiler) visit_aug_assign(node AugAssign) string {
	target := t.visit_expr(node.target)
	val := t.visit_expr(node.value)
	op_type := get_op_type(node.op)
	// FloorDiv: V / truncates toward zero, Python // floors toward -inf
	if op_type == 'FloorDiv' {
		t.add_using('math')
		mut left_ann := get_expr_annotation(node.target)
		mut right_ann := get_expr_annotation(node.value)
		if left_ann == '' {
			left_ann = t.infer_expr_type(node.target)
		}
		if right_ann == '' {
			right_ann = t.infer_expr_type(node.value)
		}
		is_float := left_ann in ['f64', 'float', 'f32'] || right_ann in ['f64', 'float', 'f32']
		if is_float {
			return '${target} = math.floor(${target} / ${val})'
		}
		return '${target} = math.divide_floored(${target}, ${val}).quot'
	}
	// Pow has no V operator; expand to assignment with math function
	if op_type == 'Pow' {
		t.add_using('math')
		mut left_ann := get_expr_annotation(node.target)
		mut right_ann := get_expr_annotation(node.value)
		if left_ann == '' {
			left_ann = t.infer_expr_type(node.target)
		}
		if right_ann == '' {
			right_ann = t.infer_expr_type(node.value)
		}
		is_float := left_ann in ['f64', 'float', 'f32'] || right_ann in ['f64', 'float', 'f32']
		// Negative exponent: Python auto-promotes to float (x **= -1 gives float)
		is_neg_exp := node.value is UnaryOp && (node.value as UnaryOp).op is USub
		if is_float || is_neg_exp {
			return '${target} = math.pow(${target}, ${val})'
		}
		return '${target} = math.powi(${target}, ${val})'
	}
	// AugAssign has operator, not unary operator - convert to symbol
	op_sym := match node.op {
		Add { '+' }
		Sub { '-' }
		Mult { '*' }
		Div { '/' }
		Mod { '%' }
		Pow { '**' }
		LShift { '<<' }
		RShift { '>>' }
		BitOr { '|' }
		BitXor { '^' }
		BitAnd { '&' }
		FloorDiv { '//' }
		else { '?' }
	}
	return '${target} ${op_sym}= ${val}'
}

// visit_ann_assign emits V code for an AnnAssign statement.
pub fn (mut t VTranspiler) visit_ann_assign(node AnnAssign) string {
	target := t.visit_expr(node.target)
	type_str := t.typename_from_annotation(node.annotation)

	mut kw := ''
	if node.target is Name {
		n := node.target as Name
		if n.is_mutable {
			kw = 'mut '
		}
	}

	// Attribute targets (self.x) are struct fields — use = not :=
	is_attr := node.target is Attribute
	op := if is_attr { '=' } else { ':=' }

	// Track variable type from annotation
	if node.target is Name && type_str != '' {
		t.var_types[(node.target as Name).id] = type_str
	}

	if val := node.value {
		val_str := t.visit_expr(val)

		// Special handling for list initialization
		if val is List {
			lst := val as List
			if lst.elts.len > 0 {
				mut elts := []string{}
				first_val := t.visit_expr(lst.elts[0])
				// Cast first element if needed for type inference
				if type_str.starts_with('[]') {
					inner_type := type_str[2..]
					if inner_type in v_width_rank {
						elts << '${inner_type}(${first_val})'
					} else {
						elts << first_val
					}
				} else {
					elts << first_val
				}
				for i := 1; i < lst.elts.len; i++ {
					elts << t.visit_expr(lst.elts[i])
				}
				return '${kw}${target} ${op} [${elts.join(', ')}]'
			}
			return '${kw}${target} ${op} ${t.zero_value_for(type_str)}'
		}

		return '${kw}${target} ${op} ${val_str}'
	}

	return '${kw}${target} ${op} ${t.zero_value_for(type_str)}'
}

// zero_value_for returns a V zero-value expression for the named type.
pub fn (t VTranspiler) zero_value_for(typ string) string {
	return zero_value_for_type(typ)
}

// visit_for emits V code for a For loop.
pub fn (mut t VTranspiler) visit_for(node For) string {
	mut target := t.visit_expr(node.target)
	mut buf := []string{}

	// Handle for/else pattern - V doesn't have it, use has_break flag
	has_else := node.orelse.len > 0

	if has_else {
		buf << 'has_break := false'
	}

	// Support tuple/list loop targets with V syntax: for a, b in ...
	if node.target is Tuple || node.target is List {
		elts := if node.target is Tuple {
			(node.target as Tuple).elts
		} else {
			(node.target as List).elts
		}
		mut target_names := []string{}
		mut all_names := true
		for e in elts {
			if e is Name {
				target_names << t.visit_expr(e)
			} else {
				all_names = false
				break
			}
		}
		if all_names && target_names.len > 0 {
			// V allows at most two iteration variables, but Python commonly unpacks
			// three or more (e.g. `for a, b, c in d.values()`). Bind the sequence
			// once and destructure with indexing instead.
			mut iter_is_special := false
			if node.iter is Call {
				call := node.iter as Call
				if call.func is Name {
					n := (call.func as Name).id
					iter_is_special = n in ['enumerate', 'zip', 'reversed']
				}
			}
			if target_names.len > 2 && !iter_is_special {
				seq := t.new_tmp('seq')
				item := t.new_tmp('item')
				buf << '${seq} := ${t.visit_expr(node.iter)}'
				buf << 'for ${item} in ${seq} {'
				for k, name in target_names {
					buf << t.indent_code('${name} := ${item}[${k}]', 2)
				}
				buf << t.visit_body_stmts(node.body, 2)
				buf << '\t}'
				return buf.join('\n')
			}
			target = target_names.join(', ')

			// enumerate(seq) => for i, v in seq
			if node.iter is Call {
				call := node.iter as Call
				if call.func is Name {
					fname := (call.func as Name).id
					if fname == 'enumerate' && target_names.len == 2 && call.args.len > 0 {
						iter0 := t.visit_expr(call.args[0])
						buf << 'for ${target_names[0]}, ${target_names[1]} in ${iter0} {'
						buf << t.visit_body_stmts(node.body, 1)
						buf << '}'
						if has_else {
							buf << 'if has_break != true {'
							buf << t.visit_body_stmts(node.orelse, 1)
							buf << '}'
						}
						return buf.join('\n')
					}
					// zip(a, b) => for i, x in a { y := b[i]; ... }
					if fname == 'zip' && target_names.len == 2 && call.args.len >= 2 {
						left := t.visit_expr(call.args[0])
						right := t.visit_expr(call.args[1])
						idx := t.new_tmp('zipi')
						buf << 'for ${idx}, ${target_names[0]} in ${left} {'
						buf << '\t${target_names[1]} := ${right}[${idx}]'
						buf << t.visit_body_stmts(node.body, 1)
						buf << '}'
						if has_else {
							buf << 'if has_break != true {'
							buf << t.visit_body_stmts(node.orelse, 1)
							buf << '}'
						}
						return buf.join('\n')
					}
				}
			}
		}
	}

	// Check for range with step
	mut for_expr := ''
	if node.iter is Call {
		call := node.iter as Call
		if call.func is Name {
			fname := (call.func as Name).id
			if fname == 'range' && call.args.len == 3 {
				start := t.visit_expr(call.args[0])
				end := t.visit_expr(call.args[1])
				step := t.visit_expr(call.args[2])
				// For range with step, use traditional C-style for loop
				// Detect if step is -1 and use i-- instead of i += -1
				step_op := if step == '-1' { '${target}--' } else { '${target} += ${step}' }
				buf << 'for ${target} := ${start}; ${target} < ${end}; ${step_op} {'
				buf << t.visit_body_stmts(node.body, 1)
				buf << '}'
				if has_else {
					buf << 'if has_break != true {'
					buf << t.visit_body_stmts(node.orelse, 1)
					buf << '}'
				}
				return buf.join('\n')
			} else if fname == 'range' && call.args.len == 2 {
				start := t.visit_expr(call.args[0])
				end := t.visit_expr(call.args[1])
				for_expr = '[]int{len: ${end} - ${start}, init: index + ${start}}'
			} else if fname == 'range' && call.args.len == 1 {
				end := t.visit_expr(call.args[0])
				for_expr = '[]int{len: ${end}, init: index}'
			} else {
				for_expr = t.visit_expr(node.iter)
			}
		} else {
			for_expr = t.visit_expr(node.iter)
		}
	} else {
		for_expr = t.visit_expr(node.iter)
	}

	// Track the type of the loop target variable based on the iterator type
	if node.target is Name {
		target_name := (node.target as Name).id
		// Infer element type from the iterator
		elem_type := t.infer_iter_elem_type(node.iter)
		if elem_type != '' {
			t.var_types[target_name] = elem_type
		}
	}

	// Emit for loop
	buf << 'for ${target} in ${for_expr} {'
	buf << t.visit_body_stmts(node.body, 1)
	buf << '}'

	if has_else {
		buf << 'if has_break != true {'
		buf << t.visit_body_stmts(node.orelse, 1)
		buf << '}'
	}

	return buf.join('\n')
}

// visit_async_for emits V code for an AsyncFor loop (converted to sync).
pub fn (mut t VTranspiler) visit_async_for(node AsyncFor) string {
	mut buf := []string{}
	target := t.visit_expr(node.target)
	if node.iter is Call {
		iter_call := node.iter as Call
		producer := t.visit_expr(iter_call.func)
		mut producer_args := []string{}
		for arg in iter_call.args {
			producer_args << t.visit_expr(arg)
		}
		for kw in iter_call.keywords {
			producer_args << t.visit_expr(kw.value)
		}
		ch := t.new_tmp('ch')
		buf << '// async for lowered to goroutine + channel'
		elem_type := t.infer_iter_elem_type(node.iter)
		ch_type := if elem_type.len > 0 { elem_type } else { 'Any' }
		if ch_type == 'Any' {
			t.generated_code_has_any_type = true
		}
		buf << '${ch} := chan ${ch_type}{}'
		mut all_args := producer_args.clone()
		all_args << ch
		buf << 'go ${producer}(${all_args.join(', ')})'
		buf << 'for ${target} in ${ch} {'
		buf << t.visit_body_stmts(node.body, 1)
		buf << '}'
		if node.orelse.len > 0 {
			buf << '// NOTE: async for/else lowered without break tracking'
			buf << t.visit_body_stmts(node.orelse, 0)
		}
		return buf.join('\n')
	}

	buf << '// WARNING: async for lowered to sync for fallback'
	f := For{
		target:       node.target
		iter:         node.iter
		body:         node.body
		orelse:       node.orelse
		type_comment: node.type_comment
		loc:          node.loc
		level:        node.level
	}
	buf << t.visit_for(f)
	return buf.join('\n')
}

// visit_while emits V code for a While loop.
pub fn (mut t VTranspiler) visit_while(node While) string {
	mut buf := []string{}

	// Check for infinite loop (while True)
	if node.test is Constant {
		c := node.test as Constant
		if c.value is bool && (c.value as bool) == true {
			buf << 'for {'
			buf << t.visit_body_stmts(node.body, 1)
			buf << '}'
			return buf.join('\n')
		}
	}

	// Check for walrus operator in while condition - convert to infinite loop with break
	if has_walrus_in_compare(node.test) {
		parts := t.extract_walrus_parts(node.test)
		if parts.len == 2 {
			buf << 'for {'
			buf << '\t${parts[0]}'
			buf << '\tif !(${parts[1]}) {'
			buf << '\t\tbreak'
			buf << '\t}'
			buf << ''
			buf << t.visit_body_stmts(node.body, 1)
			buf << '}'
			return buf.join('\n')
		}
	}

	test := t.visit_expr(node.test)
	buf << 'for ${test} {'
	buf << t.visit_body_stmts(node.body, 1)
	buf << '}'

	return buf.join('\n')
}

// visit_if emits V code for an If statement.
pub fn (mut t VTranspiler) visit_if(node If) string {
	mut buf := []string{}

	// Check for walrus operator in condition - hoist assignment before if
	if has_walrus_in_compare(node.test) {
		parts := t.extract_walrus_parts(node.test)
		if parts.len == 2 {
			buf << parts[0]
			buf << 'if ${parts[1]} {'
		} else {
			test := t.visit_expr(node.test)
			buf << 'if ${test} {'
		}
	} else {
		test := t.visit_expr(node.test)
		buf << 'if ${test} {'
	}
	buf << t.visit_body_stmts(node.body, 1)

	if node.orelse.len > 0 {
		// Check if it's an elif
		if node.orelse.len == 1 && node.orelse[0] is If {
			else_if := node.orelse[0] as If
			buf << '} else ${t.visit_if(else_if)}'
		} else {
			buf << '} else {'
			buf << t.visit_body_stmts(node.orelse, 1)
			buf << '}'
		}
	} else {
		buf << '}'
	}

	return buf.join('\n')
}

// visit_with emits V code for a With statement (uses `if true {}` for scoping).
pub fn (mut t VTranspiler) visit_with(node With) string {
	mut buf := []string{}

	buf << 'if true {'
	for item in node.items {
		context := t.visit_expr(item.context_expr)
		mut is_file_handle := false
		if vars := item.optional_vars {
			target := t.visit_expr(vars)
			// Check if target is mutable
			mut kw := ''
			if vars is Name {
				n := vars as Name
				if n.is_mutable || t.extra_mut_vars[n.id] {
					kw = 'mut '
				}
			}
			// File objects opened with open()/os.create()/os.open() should always be mut
			if item.context_expr is Call {
				ctx_call := item.context_expr as Call
				if ctx_call.func is Name {
					fn_name := (ctx_call.func as Name).id
					if fn_name == 'open' {
						kw = 'mut '
						is_file_handle = true
					}
				}
			}
			// Check if context is os.create or os.open
			if context.starts_with('os.create(') || context.starts_with('os.open(') {
				kw = 'mut '
				is_file_handle = true
			}
			buf << '\t${kw}${target} := ${context}'
			// Ensure file handles are closed when leaving the with-block scope
			if is_file_handle {
				buf << '\tdefer { ${target}.close() }'
			}
		} else {
			buf << '\t${context}'
		}
	}

	buf << t.visit_body_stmts(node.body, 1)

	buf << '}'

	return buf.join('\n')
}

// visit_async_with emits V code for an AsyncWith statement (converted to sync).
pub fn (mut t VTranspiler) visit_async_with(node AsyncWith) string {
	mut buf := []string{}
	buf << '// WARNING: async with converted to sync with defer'

	w := With{
		items:        node.items
		body:         node.body
		type_comment: node.type_comment
		loc:          node.loc
	}
	buf << t.visit_with(w)

	return buf.join('\n')
}

// visit_raise emits V code for a Raise statement.
pub fn (mut t VTranspiler) visit_raise(node Raise) string {
	if exc := node.exc {
		mut msg := ''
		if exc is Call {
			call := exc as Call
			fname := t.visit_expr(call.func)
			arg := if call.args.len > 0 { t.visit_expr(call.args[0]) } else { "''" }
			msg = "'${fname}: ' + ${arg}"
		} else {
			msg = "'${t.visit_expr(exc)}'"
		}
		// raise X from Y — append cause to message
		if cause := node.cause {
			cause_str := t.visit_expr(cause)
			return "panic(${msg} + ' (caused by: ' + ${cause_str}.str() + ')')"
		}
		return 'panic(${msg})'
	}
	// bare `raise` — re-raise inside except handler; use generic panic
	return "panic('re-raise')"
}

// visit_try emits V code for a Try statement.
// V uses Result types and `or {}` blocks instead of exceptions; we emit the
// try body as-is and each except handler inside an `// except` comment header
// followed by the handler body as real (but guarded) V code so it stays visible
// and compilable after manual adaptation.
pub fn (mut t VTranspiler) visit_try(node Try) string {
	mut buf := []string{}
	has_handlers := node.handlers.len > 0
	mut trystar_member_types := []string{}
	mut trystar_synth_dispatch := false
	if node.is_exception_group {
		for stmt in node.body {
			t.collect_exception_group_member_types_from_stmt(stmt, mut trystar_member_types)
		}
		trystar_synth_dispatch = trystar_member_types.len > 0
	}

	// TryStar (Python 3.11 except*) — V has no ExceptionGroup support.
	if node.is_exception_group {
		buf << '// WARNING: except* (ExceptionGroup) is not supported in V.'
		buf << '// Translate each except* handler manually using goroutines or error unions.'
	}

	t.emit_try_finally_defer(mut buf, node.finalbody)

	// Emit try body directly — wrap fallible calls with `or {}` manually
	if has_handlers {
		buf << '// try: (V: wrap fallible calls below with `or {}`)'
	}
	if node.is_exception_group && trystar_synth_dispatch {
		buf << '// except* synthesized dispatch for literal ExceptionGroup'
	}
	for stmt in node.body {
		buf << t.visit_stmt(stmt)
	}

	t.emit_try_else_scaffold(mut buf, node.orelse)

	// Emit each except handler with real body code inside a dead-code block
	// so the logic is visible and easy to adapt.
	for handler in node.handlers {
		meta := t.build_except_handler_meta(handler)
		if meta.bound_name.len > 0 {
			// Temporarily bind the exception var as string so uses compile.
			t.var_types[meta.bound_name] = 'string'
		}
		buf << meta.header
		buf << '// NOTE: V uses Result types; adapt body to use `or { ... }` blocks'
		if node.is_exception_group && trystar_synth_dispatch {
			t.emit_trystar_handler_body(mut buf, handler, meta.type_names, trystar_member_types)
			if meta.bound_name.len > 0 {
				t.var_types.delete(meta.bound_name)
			}
			continue
		}
		if node.is_exception_group {
			t.emit_nonexecuting_stmt_scaffold(mut buf, handler.body,
				'// NOTE: except* handler scaffold; body preserved for manual translation')
		} else {
			// Emit handler body as real code for non-TryStar fallback mode.
			for stmt in handler.body {
				buf << t.visit_stmt(stmt)
			}
		}
		// Clean up temporary binding
		if meta.bound_name.len > 0 {
			t.var_types.delete(meta.bound_name)
		}
	}

	return buf.join('\n')
}

struct ExceptHandlerMeta {
mut:
	header     string
	type_names []string
	bound_name string
}

fn (mut t VTranspiler) emit_try_finally_defer(mut buf []string, finalbody []Stmt) {
	if finalbody.len == 0 {
		return
	}
	buf << 'defer {'
	for stmt in finalbody {
		result := t.visit_stmt(stmt)
		for line in result.split('\n') {
			if line.len > 0 {
				buf << '\t${line}'
			}
		}
	}
	buf << '}'
}

fn (mut t VTranspiler) emit_try_else_scaffold(mut buf []string, orelse []Stmt) {
	if orelse.len == 0 {
		return
	}
	buf << '// else:'
	buf << '// NOTE: runs only when try body has no exception in Python'
	t.emit_nonexecuting_stmt_scaffold(mut buf, orelse, '')
}

fn (mut t VTranspiler) emit_nonexecuting_stmt_scaffold(mut buf []string, stmts []Stmt, note string) {
	if note != '' {
		buf << note
	}
	buf << 'if false {'
	for stmt in stmts {
		result := t.visit_stmt(stmt)
		for line in result.split('\n') {
			if line.len > 0 {
				buf << '\t${line}'
			}
		}
	}
	buf << '}'
}

fn (mut t VTranspiler) build_except_handler_meta(handler ExceptHandler) ExceptHandlerMeta {
	mut meta := ExceptHandlerMeta{
		header:     '// except:'
		type_names: []string{}
		bound_name: ''
	}
	if typ := handler.typ {
		mut typ_name := ''
		if typ is Tuple {
			mut names := []string{}
			for e in (typ as Tuple).elts {
				n := t.visit_expr(e)
				names << n
				meta.type_names << n
			}
			typ_name = names.join(' | ')
		} else {
			typ_name = t.visit_expr(typ)
			meta.type_names << typ_name
		}
		if name := handler.name {
			meta.header = '// except ${typ_name} as ${name}:'
			meta.bound_name = name
		} else {
			meta.header = '// except ${typ_name}:'
		}
	}
	return meta
}

fn (mut t VTranspiler) emit_trystar_handler_body(mut buf []string, handler ExceptHandler, handler_type_names []string, trystar_member_types []string) {
	mut matched := false
	for n in handler_type_names {
		if n in trystar_member_types {
			matched = true
			break
		}
	}
	if matched {
		buf << '// NOTE: matched synthetic ExceptionGroup member type(s): ${handler_type_names.join(', ')}'
		for stmt in handler.body {
			buf << t.visit_stmt(stmt)
		}
		return
	}
	t.emit_nonexecuting_stmt_scaffold(mut buf, handler.body,
		'// NOTE: except* handler scaffold; body preserved for manual translation')
}

fn (mut t VTranspiler) extract_exception_group_member_types(node Raise) ?[]string {
	if exc := node.exc {
		if exc is Call {
			call := exc as Call
			if call.func is Name && (call.func as Name).id == 'ExceptionGroup' && call.args.len >= 2 {
				members_arg := call.args[1]
				if members_arg is List {
					mut member_types := []string{}
					for elt in (members_arg as List).elts {
						if elt is Call {
							member_call := elt as Call
							if member_call.func is Name {
								member_types << (member_call.func as Name).id
							}
						}
					}
					if member_types.len > 0 {
						return member_types
					}
				}
			}
		}
	}
	return none
}

fn append_unique_strings(mut dst []string, src []string) {
	for n in src {
		if n !in dst {
			dst << n
		}
	}
}

fn (mut t VTranspiler) collect_exception_group_member_types_from_stmts(stmts []Stmt, mut member_types []string) {
	for s in stmts {
		t.collect_exception_group_member_types_from_stmt(s, mut member_types)
	}
}

fn (mut t VTranspiler) collect_exception_group_member_types_from_stmt(stmt Stmt, mut member_types []string) {
	match stmt {
		Raise {
			if types := t.extract_exception_group_member_types(stmt) {
				append_unique_strings(mut member_types, types)
			}
		}
		If {
			t.collect_exception_group_member_types_from_stmts(stmt.body, mut member_types)
			t.collect_exception_group_member_types_from_stmts(stmt.orelse, mut member_types)
		}
		For {
			t.collect_exception_group_member_types_from_stmts(stmt.body, mut member_types)
			t.collect_exception_group_member_types_from_stmts(stmt.orelse, mut member_types)
		}
		While {
			t.collect_exception_group_member_types_from_stmts(stmt.body, mut member_types)
			t.collect_exception_group_member_types_from_stmts(stmt.orelse, mut member_types)
		}
		Try {
			t.collect_exception_group_member_types_from_stmts(stmt.body, mut member_types)
			for h in stmt.handlers {
				t.collect_exception_group_member_types_from_stmts(h.body, mut member_types)
			}
			t.collect_exception_group_member_types_from_stmts(stmt.orelse, mut member_types)
			t.collect_exception_group_member_types_from_stmts(stmt.finalbody, mut member_types)
		}
		With {
			t.collect_exception_group_member_types_from_stmts(stmt.body, mut member_types)
		}
		else {}
	}
}

// visit_assert emits V code for an Assert statement.
pub fn (mut t VTranspiler) visit_assert(node Assert) string {
	test := t.visit_expr(node.test)
	return 'assert ${test}'
}

// visit_type_alias emits V code for Python 3.12+ `type X = Y` statements.
pub fn (mut t VTranspiler) visit_type_alias(node TypeAlias) string {
	name := t.visit_expr(node.name)
	value := t.typename_from_annotation(node.value)
	if value.len > 0 {
		return 'type ${name} = ${value}'
	}
	return 'type ${name} = ${t.visit_expr(node.value)}'
}

// is_simple_match_pattern returns true if a pattern can be represented as a
// single V match value (a constant, singleton, attribute access, or MatchOr of
// the same).
fn is_simple_match_pattern(p MatchPattern) bool {
	match p {
		MatchValue {
			return true
		}
		MatchSingleton {
			return true
		}
		MatchAs {
			return p.name == none && p.pattern == none
		} // bare wildcard _
		MatchOr {
			for sub in p.patterns {
				if !is_simple_match_pattern(sub) {
					return false
				}
			}
			return true
		}
		else {
			return false
		}
	}
}

// emit_match_pattern_value renders a simple pattern as its V literal value.
fn (mut t VTranspiler) emit_match_pattern_value(p MatchPattern) string {
	match p {
		MatchValue {
			return t.visit_expr(p.value)
		}
		MatchSingleton {
			return p.value
		}
		MatchOr {
			mut vals := []string{}
			for sub in p.patterns {
				vals << t.emit_match_pattern_value(sub)
			}
			return vals.join(', ')
		}
		else {
			return '_'
		}
	}
}

// emit_pattern_condition builds an `if`-chain condition string for a complex
// pattern that cannot be represented as a plain V match value.
// Returns '' for a bare wildcard (else branch).
fn (mut t VTranspiler) emit_pattern_condition(subject string, p MatchPattern) string {
	match p {
		MatchValue {
			return '${subject} == ${t.visit_expr(p.value)}'
		}
		MatchSingleton {
			return '${subject} == ${p.value}'
		}
		MatchAs {
			if p.name == none && p.pattern == none {
				return '' // wildcard — always matches
			}
			if inner := p.pattern {
				return t.emit_pattern_condition(subject, inner)
			}
			return '' // capture-only — always matches
		}
		MatchOr {
			mut parts := []string{}
			for sub in p.patterns {
				c := t.emit_pattern_condition(subject, sub)
				if c.len > 0 {
					parts << c
				}
			}
			return parts.join(' || ')
		}
		MatchSequence {
			// Emit length check plus element comparisons for fixed-length sequences
			mut parts := []string{}
			mut fixed_len := 0
			mut has_star := false
			for sp in p.patterns {
				if sp is MatchStar {
					has_star = true
				} else {
					fixed_len++
				}
			}
			if has_star {
				parts << '${subject}.len >= ${fixed_len}'
			} else {
				parts << '${subject}.len == ${p.patterns.len}'
			}
			mut elem_idx := 0
			for sp in p.patterns {
				if sp is MatchStar {
					continue
				}
				elem_cond := t.emit_pattern_condition('${subject}[${elem_idx}]', sp)
				if elem_cond.len > 0 {
					parts << elem_cond
				}
				elem_idx++
			}
			return parts.join(' && ')
		}
		MatchMapping {
			mut parts := []string{}
			for i, k in p.keys {
				key_str := t.visit_expr(k)
				parts << '${key_str} in ${subject}'
				vp := p.patterns[i]
				val_cond := t.emit_pattern_condition('${subject}[${key_str}]', vp)
				if val_cond.len > 0 {
					parts << val_cond
				}
			}
			return parts.join(' && ')
		}
		MatchClass {
			cls_str := t.visit_expr(p.cls)
			mut parts := []string{}
			parts << '${subject} is ${cls_str}'
			for i, attr in p.kwd_attrs {
				vp := p.kwd_patterns[i]
				val_cond := t.emit_pattern_condition('${subject}.${attr}', vp)
				if val_cond.len > 0 {
					parts << val_cond
				}
			}
			return parts.join(' && ')
		}
		MatchStar {
			return ''
		}
	}
}

// emit_pattern_bindings emits any variable bindings introduced by a pattern,
// e.g. `case [first, *rest]:` binds `first` and `rest`.
fn (mut t VTranspiler) emit_pattern_bindings(subject string, p MatchPattern) []string {
	mut lines := []string{}
	match p {
		MatchAs {
			if name := p.name {
				if inner := p.pattern {
					// `case <pat> as name:` — bind after the inner pattern
					inner_lines := t.emit_pattern_bindings(subject, inner)
					lines << inner_lines
				}
				lines << '${name} := ${subject}'
			}
		}
		MatchOr {
			// OR patterns cannot introduce bindings (Python rule), nothing to bind
		}
		MatchSequence {
			mut elem_idx := 0
			mut star_idx := -1
			for i, sp in p.patterns {
				if sp is MatchStar {
					star_idx = i
					break
				}
				elem_idx++
			}
			for i, sp in p.patterns {
				if sp is MatchStar {
					name := (sp as MatchStar).name or { continue }
					end_count := p.patterns.len - i - 1
					if end_count > 0 {
						lines << '${name} := ${subject}[${i}..${subject}.len - ${end_count}]'
					} else {
						lines << '${name} := ${subject}[${i}..]'
					}
					_ = star_idx
				} else {
					elem_str := '${subject}[${i}]'
					sub_binds := t.emit_pattern_bindings(elem_str, sp)
					lines << sub_binds
					if sp is MatchAs {
						// already handled by recursive call
					} else if sp is MatchValue || sp is MatchSingleton {
						// no binding
					}
					_ = elem_idx
				}
			}
		}
		MatchMapping {
			for i, k in p.keys {
				key_str := t.visit_expr(k)
				sub_binds := t.emit_pattern_bindings('${subject}[${key_str}]', p.patterns[i])
				lines << sub_binds
			}
			if rest := p.rest {
				// `**rest` capture — not directly expressible in V; emit comment
				lines << '// ${rest} := remaining keys (not supported in V)'
			}
		}
		MatchClass {
			for i, attr in p.kwd_attrs {
				sub_binds := t.emit_pattern_bindings('${subject}.${attr}', p.kwd_patterns[i])
				lines << sub_binds
			}
		}
		else {}
	}

	return lines
}

// visit_match emits V code for a Python match statement.
// Simple value/singleton patterns are lowered to a V `match` statement.
// Complex patterns (sequences, mappings, class patterns, guards) are lowered
// to an `if`/`else if` chain.
pub fn (mut t VTranspiler) visit_match(node Match) string {
	subject := t.visit_expr(node.subject)

	// Decide strategy: use V `match` only when ALL cases are simple values
	// (no guards, no bindings, no structural patterns).
	mut all_simple := true
	for c in node.cases {
		if c.guard != none {
			all_simple = false
			break
		}
		if !is_simple_match_pattern(c.pattern) {
			all_simple = false
			break
		}
		// MatchAs with a name binding cannot go into a V match arm directly
		if c.pattern is MatchAs {
			ma := c.pattern as MatchAs
			if ma.name != none {
				all_simple = false
				break
			}
		}
	}

	if all_simple {
		return t.emit_v_match(subject, node.cases)
	}
	return t.emit_if_chain_match(subject, node.cases)
}

// emit_v_match emits a V `match` statement for simple patterns.
fn (mut t VTranspiler) emit_v_match(subject string, cases []MatchCase) string {
	mut buf := []string{}
	buf << 'match ${subject} {'
	for c in cases {
		body_str := t.visit_body_stmts(c.body, 1)
		match c.pattern {
			MatchAs {
				// bare wildcard → else
				buf << '\telse {'
				buf << body_str
				buf << '\t}'
			}
			else {
				val := t.emit_match_pattern_value(c.pattern)
				buf << '\t${val} {'
				buf << body_str
				buf << '\t}'
			}
		}
	}
	buf << '}'
	return buf.join('\n')
}

// emit_if_chain_match emits an if/else-if chain for complex match patterns.
fn (mut t VTranspiler) emit_if_chain_match(subject string, cases []MatchCase) string {
	mut buf := []string{}
	for i, c in cases {
		cond := t.emit_pattern_condition(subject, c.pattern)
		bindings := t.emit_pattern_bindings(subject, c.pattern)
		body_str := t.visit_body_stmts(c.body, 1)

		// For a bare MatchAs capture (case x if guard:), substitute the capture
		// name with the subject in the guard so `if x < 0` becomes `if n < 0`.
		capture_subst := if c.pattern is MatchAs {
			ma := c.pattern as MatchAs
			if n := ma.name {
				if ma.pattern == none {
					n
				} else {
					''
				}
			} else {
				''
			}
		} else {
			''
		}

		// Apply guard; when cond is empty the guard is the full condition.
		mut full_cond := cond
		if guard := c.guard {
			mut guard_expr := t.visit_expr(guard)
			// Inline capture variable → subject for pure-capture MatchAs
			if capture_subst.len > 0 {
				// Replace whole-word occurrences of the capture name with subject
				guard_expr = guard_expr.replace(capture_subst, subject)
			}
			if full_cond.len == 0 {
				full_cond = guard_expr
			} else {
				full_cond = '${full_cond} && ${guard_expr}'
			}
		}

		is_wildcard := full_cond.len == 0
		kw := if i == 0 { 'if' } else { '} else if' }

		if is_wildcard {
			buf << '} else {'
			for b in bindings {
				buf << t.indent_code(b, 1)
			}
			buf << body_str
		} else {
			buf << '${kw} ${full_cond} {'
			for b in bindings {
				buf << t.indent_code(b, 1)
			}
			buf << body_str
		}
	}
	buf << '}'
	return buf.join('\n')
}

// visit_import handles Python import statements, mapping known modules to V imports.
pub fn (mut t VTranspiler) visit_import(node Import) string {
	mut lines := []string{}
	for alias in node.names {
		lines << t.map_python_import(alias.name)
	}
	return lines.filter(it.len > 0).join('\n')
}

// visit_import_from handles Python 'from X import Y', mapping the module.
pub fn (mut t VTranspiler) visit_import_from(node ImportFrom) string {
	module_name := node.mod or { '' }
	// `from proj.mod import name` binds `name`; record where it now lives so
	// every reference can be qualified with its V module.
	if t.registry.contains(module_name) {
		v_mod := t.registry.v_module_for(module_name)
		// A module never imports itself: V merges a directory into one module.
		if !t.registry.is_project_root(module_name) && v_mod != t.module_name {
			t.add_using(v_mod)
		}
		for alias in node.names {
			local := alias.asname or { alias.name }
			// A relative import names a sibling module; resolve it against the
			// current module's package.
			target := if alias.name == '' { module_name } else { module_name + '.' + alias.name }
			if t.registry.contains(target) && !t.registry.is_project_root(target) {
				t.import_aliases[local] = t.registry.v_module_for(target)
				continue
			}
			if v_mod != t.module_name {
				t.import_aliases[local] = v_mod
			}
		}
		t.seed_imported_classes(module_name)
		return ''
	}
	return t.map_python_import(module_name)
}

// map_python_import converts a Python module name to a V import line or comment.
fn (mut t VTranspiler) map_python_import(py_module string) string {
	// A module belonging to the scanned project maps to a V module of the same
	// layout, so it needs a real import rather than a "no equivalent" comment.
	if t.registry.contains(py_module) {
		if !t.registry.is_project_root(py_module) {
			t.add_using(t.registry.v_module_for(py_module))
		}
		return ''
	}
	// Strip sub-module suffix for top-level lookup first
	top := py_module.split('.')[0]
	// Check exact match first, then top-level
	v_mod := if py_module in python_to_v_import {
		python_to_v_import[py_module]
	} else if top in python_to_v_import {
		python_to_v_import[top]
	} else {
		'!// import ${py_module}: no known V equivalent'
	}
	if v_mod == '' {
		return '' // silently suppressed
	}
	if v_mod.starts_with('!') {
		return v_mod[1..] // emit raw comment
	}
	// Register the V module so the header import block is emitted
	t.add_using(v_mod)
	t.imported_modules[top] = true
	return ''
}

// visit_global emits a comment for Python global declarations.
// V supports __global but it is strongly discouraged; prefer passing as a
// mut parameter or holding state in a struct field.
pub fn (mut t VTranspiler) visit_global(node Global) string {
	t.has_global_decl = true
	names := node.names.join(', ')
	return '// global ${names}: prefer mut parameter or struct field over __global'
}

// visit_nonlocal emits a comment for Python nonlocal declarations.
// V closures capture mut variables by reference automatically.
pub fn (mut t VTranspiler) visit_nonlocal(node Nonlocal) string {
	names := node.names.join(', ')
	return '// nonlocal ${names}: V closures capture mut variables by reference automatically'
}

// visit_expr_stmt emits V code for an expression statement (ExprStmt).
pub fn (mut t VTranspiler) visit_expr_stmt(node ExprStmt) string {
	// Check for ellipsis
	if node.value is Constant {
		c := node.value as Constant
		if c.value is EllipsisValue {
			return '// ...'
		}
		// A bare string used as a statement is a Python no-op. Emitting it as a V
		// expression statement is a type error, so keep the text as a comment.
		if c.value is string {
			mut out := []string{}
			for raw_line in (c.value as string).split('\n') {
				out << '// ${raw_line.trim_space()}'
			}
			return out.join('\n')
		}
	}
	result := t.visit_expr(node.value)
	if result.len == 0 {
		return ''
	}
	return result
}

// visit_constant emits V code for a Constant expression.
pub fn (mut t VTranspiler) visit_constant(node Constant) string {
	match node.value {
		NoneValue {
			return 'none'
		}
		EllipsisValue {
			// Represent Python ellipsis as V placeholder `_` so assignments
			// like `e = ...` become `e = _`. Do not include a trailing
			// comment here because ellipsis may appear inside larger
			// expressions; comments would truncate the rest of the line.
			return '_'
		}
		ComplexValue {
			cv := node.value as ComplexValue
			// Use V's math.complex constructor
			t.add_using('math')
			return 'math.complex(${cv.real}, ${cv.imag})'
		}
		bool {
			return if node.value as bool { 'true' } else { 'false' }
		}
		int {
			// Emit numeric literal directly (no .str() needed in generated V code)
			return '${node.value as int}'
		}
		i64 {
			return '${node.value as i64}'
		}
		f64 {
			return '${node.value as f64}'
		}
		string {
			return v_string_literal(node.value as string)
		}
		BytesValue {
			bv := node.value as BytesValue
			return bytes_to_v_literal(bv.data)
		}
	}
}

// visit_name emits V code for a Name expression.
pub fn (mut t VTranspiler) visit_name(node Name) string {
	// Check if this identifier was escaped due to V built-in type name conflict
	if t.escaped_identifiers[node.id] or { false } {
		return '${node.id}_'
	}
	// A bare `_` is the Python throwaway target and stays as V's discard name.
	if node.id == '_' {
		return '_'
	}
	// A name bound by `from other_module import name` lives in another V
	// module, so references must be qualified.
	if prefix := t.import_aliases[node.id] {
		return '${prefix}.${escape_keyword(escape_leading_underscore(node.id))}'
	}
	return escape_keyword(escape_leading_underscore(node.id))
}

// is_path_expr returns true when expr is a known path variable, inline Path() call,
// or a chained BinOp{Div} that starts from a path.
fn (t VTranspiler) is_path_expr(expr Expr) bool {
	match expr {
		Name {
			return t.path_vars[expr.id] or { false }
		}
		Call {
			return expr.func is Name && (expr.func as Name).id == 'Path'
		}
		Attribute {
			return expr.attr in ['parent', 'stem'] && expr.value is Name && (t.path_vars[(expr.value as Name).id] or {
				false
			})
		}
		BinOp {
			return expr.op is Div && t.is_path_expr(expr.left)
		}
		else {
			return false
		}
	}
}

// collect_path_segs flattens nested path-join BinOps into a flat list of segments.
fn (mut t VTranspiler) collect_path_segs(node BinOp, mut segs []string) {
	if node.left is BinOp
		&& (node.left as BinOp).op is Div && t.is_path_expr((node.left as BinOp).left) {
		t.collect_path_segs(node.left as BinOp, mut segs)
	} else {
		segs << t.visit_expr(node.left)
	}
	segs << t.visit_expr(node.right)
}

// visit_binop emits V code for a binary operation (BinOp).
pub fn (mut t VTranspiler) visit_binop(node BinOp) string {
	left := t.visit_expr(node.left)
	right := t.visit_expr(node.right)
	mut op := op_to_symbol(get_op_type(node.op))

	// Handle power operator - V doesn't have **, use math.pow/powi
	if node.op is Pow {
		t.add_using('math')
		mut left_ann := get_expr_annotation(node.left)
		mut right_ann := get_expr_annotation(node.right)
		if left_ann == '' {
			left_ann = t.infer_expr_type(node.left)
		}
		if right_ann == '' {
			right_ann = t.infer_expr_type(node.right)
		}
		is_float := left_ann in ['f64', 'float', 'f32'] || right_ann in ['f64', 'float', 'f32']
		// Check if exponent is negative - Python auto-promotes to float for negative exponents
		is_neg_exp := node.right is UnaryOp && (node.right as UnaryOp).op is USub
		if is_float || is_neg_exp {
			return 'math.pow(${left}, ${right})'
		}
		return 'math.powi(${left}, ${right})'
	}

	// Handle Python % string formatting -> V string interpolation
	if node.op is Mod {
		if node.left is Constant {
			c := node.left as Constant
			if c.value is string {
				fmt_str := c.value as string
				mut values := []string{}
				if node.right is Tuple {
					tup := node.right as Tuple
					for elt in tup.elts {
						values << t.visit_expr(elt)
					}
				} else {
					values << right
				}
				return convert_percent_format(fmt_str, values)
			}
		}
	}

	// Path joining via / operator — Python pathlib uses / to join path segments.
	// Detect when left operand is a tracked path var or a Path(...) call result.
	if node.op is Div {
		is_path_left := t.is_path_expr(node.left)
		if is_path_left {
			t.add_using('os')
			// Flatten nested path joins: collect all segments
			mut segs := []string{}
			t.collect_path_segs(node, mut segs)
			return 'os.join_path(${segs.join(', ')})'
		}
	}

	// Handle floor division - V / truncates toward zero, Python // floors toward -inf
	// e.g. -7 // 2 = -4 in Python, -7 / 2 = -3 in V
	if node.op is FloorDiv {
		t.add_using('math')
		mut left_ann := get_expr_annotation(node.left)
		mut right_ann := get_expr_annotation(node.right)
		if left_ann == '' {
			left_ann = t.infer_expr_type(node.left)
		}
		if right_ann == '' {
			right_ann = t.infer_expr_type(node.right)
		}
		is_float := left_ann in ['f64', 'float', 'f32'] || right_ann in ['f64', 'float', 'f32']
		if is_float {
			return 'math.floor(${left} / ${right})'
		}
		return 'math.divide_floored(${left}, ${right}).quot'
	}

	// Handle string/list repetition
	if node.op is Mult {
		left_ann := get_expr_annotation(node.left)
		right_ann := get_expr_annotation(node.right)
		if right_ann == 'int' && (left_ann == 'string' || left_ann.starts_with('[]')) {
			return '${left}.repeat(${right})'
		}
		// Also check by inferring types when v_annotation is not set
		left_type := t.infer_expr_type(node.left)
		if left_type == 'string' {
			return '${left}.repeat(${right})'
		}
		// Check if left is a List literal - list repetition
		if node.left is List {
			return '${left}.repeat(${right})'
		}
	}

	// Handle list concatenation - V uses << operator
	if node.op is Add {
		mut la := get_expr_annotation(node.left)
		mut ra := get_expr_annotation(node.right)
		if la == '' {
			la = t.infer_expr_type(node.left)
		}
		if ra == '' {
			ra = t.infer_expr_type(node.right)
		}
		if la.starts_with('[]') && ra.starts_with('[]') {
			// Use IIFE (immediately invoked function expression) to concat
			// Need to capture variables in the closure
			return '(fn [${left}, ${right}] () ${la} { mut r := ${left}.clone(); r << ${right}; return r }())'
		}
	}

	// Handle int/float division - V requires explicit type conversion
	if node.op is Div {
		mut left_ann := get_expr_annotation(node.left)
		mut right_ann := get_expr_annotation(node.right)
		// Fallback to type inference if annotation is missing
		if left_ann == '' {
			left_ann = t.infer_expr_type(node.left)
		}
		if right_ann == '' {
			right_ann = t.infer_expr_type(node.right)
		}
		// If either operand is float, ensure both are float
		if left_ann == 'int' && (right_ann == 'f64' || right_ann == 'float') {
			return 'f64(${left}) ${op} ${right}'
		}
		if (left_ann == 'f64' || left_ann == 'float') && right_ann == 'int' {
			return '${left} ${op} f64(${right})'
		}
		// If right is float but left annotation is unknown/empty, wrap left in f64 to be safe
		if (right_ann == 'f64' || right_ann == 'float') && left_ann == '' {
			return 'f64(${left}) ${op} ${right}'
		}
		if (left_ann == 'f64' || left_ann == 'float') && right_ann == '' {
			return '${left} ${op} f64(${right})'
		}
	}

	// Handle bitwise operators on booleans - convert to logical operators
	mut lann := get_expr_annotation(node.left)
	mut rann := get_expr_annotation(node.right)
	if lann == '' {
		lann = t.infer_expr_type(node.left)
	}
	if rann == '' {
		rann = t.infer_expr_type(node.right)
	}
	// Convert bitwise to logical operators when both operands are booleans
	if lann == 'bool' && rann == 'bool' {
		if node.op is BitAnd {
			op = '&&'
		} else if node.op is BitOr {
			op = '||'
		} else if node.op is BitXor {
			op = '!='
		}
	}

	// Handle mixed signed/unsigned integer types - V requires explicit casts
	// Signed types: i8, i16, int, i64
	// Unsigned types: u8, u16, u32, u64
	left_signed := lann in ['i8', 'i16', 'int', 'i64']
	left_unsigned := lann in ['u8', 'u16', 'u32', 'u64']
	right_signed := rann in ['i8', 'i16', 'int', 'i64']
	right_unsigned := rann in ['u8', 'u16', 'u32', 'u64']

	// If mixing signed and unsigned, cast both to the wider type
	if (left_signed && right_unsigned) || (left_unsigned && right_signed) {
		// Use the result type annotation if available
		result_type := node.v_annotation or { '' }
		if result_type != '' {
			return '${result_type}(${left}) ${op} ${result_type}(${right})'
		}
		// Cast both to the wider of the two types
		wider := get_wider_type(lann, rann)
		return '${wider}(${left}) ${op} ${wider}(${right})'
	}

	return '${left} ${op} ${right}'
}

// visit_unaryop emits V code for a unary operation (UnaryOp).
pub fn (mut t VTranspiler) visit_unaryop(node UnaryOp) string {
	op := op_to_symbol(get_unary_op_type(node.op))
	operand := t.visit_expr(node.operand)

	if node.op is USub {
		// Wrap only compound expressions (BinOp) to preserve precedence
		if node.operand is BinOp {
			return '-(${operand})'
		}
		return '-${operand}'
	}

	if node.op is Not {
		// Wrap Compare, BoolOp, and BinOp operands so `!a == b` doesn't
		// become `(!a) == b` due to V operator precedence.
		needs_parens := node.operand is Compare || node.operand is BoolOp
			|| node.operand is BinOp
		if needs_parens {
			return '!(${operand})'
		}
	}

	return '${op}${operand}'
}

// visit_boolop emits V code for a boolean operation (BoolOp).
pub fn (mut t VTranspiler) visit_boolop(node BoolOp) string {
	op := op_to_symbol(get_bool_op_type(node.op))
	mut parts := []string{}
	for val in node.values {
		expr_str := t.visit_expr(val)
		// Wrap nested BoolOps in parentheses to avoid ambiguity
		if val is BoolOp {
			parts << '(${expr_str})'
		} else {
			parts << expr_str
		}
	}
	return parts.join(' ${op} ')
}

// visit_compare emits V code for comparison expressions (Compare).
pub fn (mut t VTranspiler) visit_compare(node Compare) string {
	left := t.visit_expr(node.left)

	if node.ops.len > 0 && node.ops[0] is In {
		// Check if right side is dict.values() - use .keys().map() for V compatibility
		comp := node.comparators[0]
		if comp is Call {
			cc := comp as Call
			if cc.func is Attribute {
				attr := cc.func as Attribute
				if attr.attr == 'values' {
					dict_obj := t.visit_expr(attr.value)
					return '${left} in ${dict_obj}.keys().map(${dict_obj}[it])'
				}
			}
		}
		right := t.visit_expr(comp)
		// Check if right side is a string - use .contains() instead of 'in'
		right_ann := get_expr_annotation(comp)
		right_type := if right_ann.len > 0 { right_ann } else { t.infer_expr_type(comp) }
		if right_type == 'string' {
			return '${right}.contains(${left})'
		}
		return '${left} in ${right}'
	}

	if node.ops.len > 0 && node.ops[0] is NotIn {
		right := t.visit_expr(node.comparators[0])
		// Check if right side is a string - use !.contains() instead of '!in'
		right_ann := get_expr_annotation(node.comparators[0])
		right_type := if right_ann.len > 0 {
			right_ann
		} else {
			t.infer_expr_type(node.comparators[0])
		}
		if right_type == 'string' {
			return '!${right}.contains(${left})'
		}
		return '${left} !in ${right}'
	}

	op := op_to_symbol(get_cmp_op_type(node.ops[0]))
	mut right := t.visit_expr(node.comparators[0])

	// When comparing a numeric CONSTANT with None, replace 'none' with '0'
	if right == 'none' && node.left is Constant {
		c := node.left as Constant
		if c.value is int || c.value is i64 || c.value is f64 {
			right = '0'
		}
	}
	if left == 'none' && node.comparators[0] is Constant {
		c := node.comparators[0] as Constant
		if c.value is int || c.value is i64 || c.value is f64 {
			return '0 ${op} ${right}'
		}
	}

	return '${left} ${op} ${right}'
}

// visit_call emits V code for function calls (Call).
pub fn (mut t VTranspiler) visit_call(node Call) string {
	fname := t.visit_expr(node.func)

	// Check if this function has mut parameters
	mut_indices := t.mut_param_indices[fname] or { []int{} }

	mut vargs := []string{}
	for i, arg in node.args {
		mut arg_str := t.visit_expr(arg)
		// Add mut keyword if this parameter index requires it
		if i in mut_indices {
			arg_str = 'mut ${arg_str}'
		}
		vargs << arg_str
	}

	// Fill in missing arguments with default values
	if defaults := t.func_defaults[fname] {
		param_count := t.func_param_count[fname] or { 0 }
		args_provided := vargs.len
		if args_provided < param_count {
			// defaults apply to the last N parameters
			// where N = defaults.len
			num_defaults := defaults.len
			first_default_idx := param_count - num_defaults

			for i in args_provided .. param_count {
				default_idx := i - first_default_idx
				if default_idx >= 0 && default_idx < defaults.len {
					vargs << defaults[default_idx]
				}
			}
		}
	}

	// re module → regex module dispatch
	re_result, re_handled := dispatch_re_func(mut t, fname, vargs)
	if re_handled {
		return re_result
	}

	// itertools module dispatch
	it_result, it_handled := dispatch_itertools_func(mut t, fname, vargs)
	if it_handled {
		return it_result
	}

	// asyncio lowers to V concurrency/runtime constructs.
	if fname == 'asyncio.run' {
		if vargs.len > 0 {
			return vargs[0]
		}
		return ''
	}
	if fname == 'asyncio.create_task' {
		if vargs.len > 0 {
			return 'go ${vargs[0]}'
		}
		return ''
	}

	// Handle string/list methods that need translation
	if node.func is Attribute {
		attr_node := node.func as Attribute
		obj := t.visit_expr(attr_node.value)
		method := attr_node.attr

		// Translate Python super().method(...) to embedded-base calls.
		if attr_node.value is Call {
			super_call := attr_node.value as Call
			if super_call.func is Name && (super_call.func as Name).id == 'super' {
				base_name := t.resolve_super_base()
				if base_name.len > 0 {
					// Base methods are emitted under their V spelling, so a
					// `super().__init__(...)` must target the base's `init`.
					v_method := python_dunder_method_names[method] or { method }
					// A base method with a `mut self` receiver needs the embedded
					// value itself declared mutable at the call site.
					mut recv := 'self'
					if t.mut_receiver_methods['${base_name}_${v_method}'] {
						recv = 'mut self'
					}
					if vargs.len > 0 {
						return '${recv}.${base_name}.${v_method}(${vargs.join(', ')})'
					}
					return '${recv}.${base_name}.${v_method}()'
				}
				return ''
			}
		}

		// pathlib.Path method translations — Path objects are strings in V.
		// Also detect inline Path(...).method() chains.
		mut effective_obj := obj
		if attr_node.value is Call {
			inner_call := attr_node.value as Call
			if inner_call.func is Name && (inner_call.func as Name).id == 'Path' {
				// Inline Path(...) — temporarily treat as path var
				if inner_call.args.len > 0 {
					effective_obj = t.visit_expr(inner_call.args[0])
				}
				t.path_vars[effective_obj] = true
			}
		}
		path_result, path_handled := dispatch_path_method(mut t, effective_obj, method, vargs)
		if path_handled {
			return path_result
		}

		// String methods
		match method {
			'strip' {
				return '${obj}.trim_space()'
			}
			'lstrip' {
				if vargs.len > 0 {
					return '${obj}.trim_left(${vargs[0]})'
				}
				return '${obj}.trim_left(" \\t\\n\\r")'
			}
			'rstrip' {
				if vargs.len > 0 {
					return '${obj}.trim_right(${vargs[0]})'
				}
				return '${obj}.trim_right(" \\t\\n\\r")'
			}
			'find' {
				if vargs.len > 0 {
					return '${obj}.index(${vargs[0]}) or { -1 }'
				}
				return '-1'
			}
			'rfind' {
				if vargs.len > 0 {
					return '${obj}.last_index(${vargs[0]}) or { -1 }'
				}
				return '-1'
			}
			'replace' {
				if vargs.len >= 2 {
					return '${obj}.replace(${vargs[0]}, ${vargs[1]})'
				}
				return obj
			}
			'split' {
				if vargs.len > 0 {
					return '${obj}.split(${vargs[0]})'
				}
				return '${obj}.split(" ")'
			}
			'join' {
				if vargs.len > 0 {
					arg_type := t.infer_expr_type(node.args[0])
					if arg_type.len == 0 || arg_type == 'Any' {
						// Fallback when iterable element type is unknown.
						// Do not add .str() — emit the iterable expression as-is.
						return '(${vargs[0]})'
					}
					return '${vargs[0]}.join(${obj})'
				}
				return obj
			}
			'upper' {
				return '${obj}.to_upper()'
			}
			'lower' {
				return '${obj}.to_lower()'
			}
			'startswith' {
				if vargs.len > 0 {
					return '${obj}.starts_with(${vargs[0]})'
				}
				return 'false'
			}
			'endswith' {
				if vargs.len > 0 {
					return '${obj}.ends_with(${vargs[0]})'
				}
				return 'false'
			}
			'format' {
				// Convert simple "...{...}...".format(...) to V interpolation
				// Support automatic {} (sequential), numeric {0}, and named {name} fields.
				if attr_node.value is Constant {
					c := attr_node.value as Constant
					if c.value is string {
						fmt_str := c.value as string

						// Precompute argument expressions
						mut arg_exprs := []string{}
						for a in node.args {
							arg_exprs << t.visit_expr(a)
						}
						mut kw_exprs := map[string]string{}
						for kw in node.keywords {
							if arg := kw.arg {
								kw_exprs[arg] = t.visit_expr(kw.value)
							}
						}

						mut sb := new_string_builder()
						mut buf := ''
						mut i := 0
						mut next_arg := 0
						for i < fmt_str.len {
							ch := fmt_str[i]
							if ch == `{` {
								// Escaped '{{'
								if i + 1 < fmt_str.len && fmt_str[i + 1] == `{` {
									buf += '{'
									i += 2
									continue
								}
								// Find closing brace
								mut j := i + 1
								for j < fmt_str.len && fmt_str[j] != `}` {
									j++
								}
								if j >= fmt_str.len {
									// unmatched, treat as literal
									buf += '{'
									i++
									continue
								}
								token := fmt_str[i + 1..j]
								// flush buffer
								if buf != '' {
									sb.write(escape_string(buf))
									buf = ''
								}
								// parse key and optional format spec after ':'
								colon := token.index(':') or { -1 }
								key := if colon >= 0 { token[0..colon] } else { token }
								fmt_spec := if colon >= 0 { token[colon + 1..] } else { '' }
								mut expr := ''

								// Support complex field lookups like 'person.name' or "data[0].name"
								if key.len > 0 && (key.contains('.') || key.contains('[')) {
									mut base := ''
									mut ops := []string{}
									mut operands := []string{}
									mut pos2 := 0
									// find base (up to first '.' or '[')
									for pos2 < key.len {
										ch2 := key[pos2]
										if (ch2 >= `a` && ch2 <= `z`)
											|| (ch2 >= `A` && ch2 <= `Z`)
											|| (ch2 >= `0` && ch2 <= `9`)
											|| ch2 == `_` {
											pos2++
											continue
										}
										break
									}
									base = key[0..pos2]

									// Parse the rest
									for pos2 < key.len {
										if key[pos2] == `.` {
											// attribute access
											pos2++
											start := pos2
											for pos2 < key.len {
												ch2 := key[pos2]
												if (ch2 >= `a` && ch2 <= `z`)
													|| (ch2 >= `A` && ch2 <= `Z`)
													|| (ch2 >= `0` && ch2 <= `9`)
													|| ch2 == `_` {
													pos2++
													continue
												}
												break
											}
											if pos2 > start {
												attr := key[start..pos2]
												ops << 'attr'
												operands << attr
											}
										} else if key[pos2] == `[` {
											// indexing - find matching ]
											pos2++
											start := pos2
											mut depth := 1
											for pos2 < key.len && depth > 0 {
												if key[pos2] == `[` {
													depth++
												} else if key[pos2] == `]` {
													depth--
													if depth == 0 {
														break
													}
												}
												pos2++
											}
											if pos2 <= key.len {
												idx_expr := key[start..pos2]
												ops << 'index'
												operands << idx_expr
												if pos2 < key.len && key[pos2] == `]` {
													pos2++
												}
											} else {
												break
											}
										} else {
											// unknown - stop
											break
										}
									}

									// Resolve base expression
									mut base_expr := ''
									if base.len > 0 {
										// numeric positional
										mut parsed := 0
										mut ok2 := true
										for bch in base.bytes() {
											if bch < `0` || bch > `9` {
												ok2 = false
												break
											}
											parsed = parsed * 10 + int(bch - `0`)
										}
										if ok2 && base.len > 0 {
											if parsed < arg_exprs.len {
												base_expr = arg_exprs[parsed]
											} else if parsed < node.args.len {
												base_expr = t.visit_expr(node.args[parsed])
											}
										} else {
											// keyword arg
											for kw in node.keywords {
												if arg := kw.arg {
													if arg == base {
														base_expr = t.visit_expr(kw.value)
														break
													}
												}
											}
											if base_expr == '' {
												base_expr = escape_keyword(base)
											}
										}
									}

									// Apply operations
									if base_expr.len > 0 {
										for idx2, opn in ops {
											if opn == 'attr' {
												p := operands[idx2]
												base_expr = '${base_expr}.${escape_identifier(p)}'
											} else if opn == 'index' {
												idxs := operands[idx2].trim_space()
												// quoted string index
												if idxs.len > 0
													&& (idxs[0] == `'` || idxs[0] == `"`) {
													q := idxs[0]
													mut inner := idxs[1..idxs.len]
													if inner.len > 0 && inner[inner.len - 1] == q {
														inner = inner[0..inner.len - 1]
													}
													lit := "'${escape_string(inner)}'"
													base_expr = '${base_expr}[${lit}]'
												} else if idxs.len > 0 {
													mut all_digits := true
													for cch in idxs.bytes() {
														if cch < `0` || cch > `9` {
															all_digits = false
															break
														}
													}
													if all_digits {
														base_expr = '${base_expr}[${idxs}]'
													} else {
														base_expr = '${base_expr}[${escape_keyword(idxs)}]'
													}
												}
											}
										}
										expr = base_expr
									}
								}

								// If expr still empty, fall back to previous logic
								if expr.len == 0 {
									if key.len == 0 {
										// automatic field
										if next_arg < arg_exprs.len {
											expr = arg_exprs[next_arg]
										}
										next_arg++
									} else {
										// numeric?
										mut parsed := 0
										mut ok := true
										for b in key.bytes() {
											if b < `0` || b > `9` {
												ok = false
												break
											}
											parsed = parsed * 10 + int(b - `0`)
										}
										if ok && key.len > 0 {
											if parsed < arg_exprs.len {
												expr = arg_exprs[parsed]
											}
										} else {
											// named field - try keyword args
											if val := kw_exprs[key] {
												expr = val
											} else {
												// fallback: use identifier as-is (escape if needed)
												expr = escape_keyword(key)
											}
										}
									}
								}
								if expr.len > 0 {
									sb.write('$')
									sb.write('{')
									sb.write(expr)
									// Append mapped format specifier if present
									if fmt_spec.len > 0 {
										mapped := map_python_format_spec(fmt_spec)
										if mapped.len > 0 {
											if mapped.starts_with('CALL:') {
												parts := mapped.split(':')
												// parts[0] == 'CALL', parts[1] == fn name
												if parts.len > 1 {
													fn_name := parts[1]
													if fn_name == 'fmt_group_int' {
														// CALL:fmt_group_int:width:zero_flag:type:sign
														width_s := if parts.len > 2 {
															parts[2]
														} else {
															''
														}
														zero_s := if parts.len > 3 {
															parts[3]
														} else {
															'0'
														}
														width_arg := if width_s != '' {
															width_s
														} else {
															'0'
														}
														zero_arg := if zero_s == '1' {
															'true'
														} else {
															'false'
														}
														sb.write('fmt_group_int(${expr}, ${width_arg}, ${zero_arg})')
													} else if fn_name == 'fmt_center' {
														// CALL:fmt_center:width
														width_s := if parts.len > 2 {
															parts[2]
														} else {
															'0'
														}
														sb.write('fmt_center(${expr}, ${width_s})')
													} else if fn_name == 'fmt_group_float' {
														// CALL:fmt_group_float:width:zero_flag:type:precision:sign
														width_s := if parts.len > 2 {
															parts[2]
														} else {
															''
														}
														zero_s := if parts.len > 3 {
															parts[3]
														} else {
															'0'
														}
														type_ch := if parts.len > 4 {
															parts[4]
														} else {
															'f'
														}
														prec_s := if parts.len > 5 {
															parts[5]
														} else {
															''
														}
														sign_ch := if parts.len > 6 {
															parts[6]
														} else {
															''
														}
														width_arg := if width_s != '' {
															width_s
														} else {
															'0'
														}
														zero_arg := if zero_s == '1' {
															'true'
														} else {
															'false'
														}
														prec_arg := if prec_s != '' {
															prec_s
														} else {
															'6'
														}
														// Cast expr to f64 for formatting
														sb.write('fmt_group_float(f64(${expr}), ${width_arg}, ${zero_arg}, ${prec_arg}, "${type_ch}", "${sign_ch}")')
													} else {
														// Unknown CALL - fallback to raw spec
														sb.write(mapped)
													}
												}
											} else {
												// mapped includes leading ':' when non-empty
												sb.write(mapped)
											}
										}
									}
									sb.write('}')
								}
								i = j + 1
								continue
							}
							// Escaped '}}'
							if ch == `}` && i + 1 < fmt_str.len && fmt_str[i + 1] == `}` {
								buf += '}'
								i += 2
								continue
							}
							// Normal char
							if ch == `'` {
								buf += "\\'"
							} else {
								buf += ch.ascii_str()
							}
							i++
						}

						if buf != '' {
							sb.write(escape_string(buf))
						}

						final_str := "'" + sb.str() + "'"
						return final_str
					}
				}
				// Fallback: return the base object unchanged
				return obj
			}
			'count' {
				if vargs.len > 0 {
					return '${obj}.count(${vargs[0]})'
				}
				return '0'
			}
			'isdigit' {
				return '(${obj}.len > 0 && ${obj}.bytes().all(fn (c u8) bool { return c.is_digit() }))'
			}
			'isalpha' {
				return '(${obj}.len > 0 && ${obj}.bytes().all(fn (c u8) bool { return c.is_letter() }))'
			}
			'isalnum' {
				return '(${obj}.len > 0 && ${obj}.bytes().all(fn (c u8) bool { return c.is_alnum() }))'
			}
			'isspace' {
				return '(${obj}.len > 0 && ${obj}.bytes().all(fn (c u8) bool { return c.is_space() }))'
			}
			'islower' {
				return '${obj}.is_lower()'
			}
			'isupper' {
				return '${obj}.is_upper()'
			}
			'istitle' {
				return '${obj}.is_title()'
			}
			'capitalize' {
				return '${obj}.capitalize()'
			}
			'title' {
				return '${obj}.title()'
			}
			'splitlines' {
				return '${obj}.split_into_lines()'
			}
			'expandtabs' {
				if vargs.len > 0 {
					return '${obj}.expand_tabs(${vargs[0]})'
				}
				return '${obj}.expand_tabs(8)'
			}
			'encode' {
				// Python bytes; ignore encoding arg — return []u8
				return '${obj}.bytes()'
			}
			'zfill' {
				// No direct V equivalent — pad with leading zeros using strings module
				t.add_using('strings')
				if vargs.len > 0 {
					return 'if ${obj}.len < ${vargs[0]} { strings.repeat(`0`, ${vargs[0]} - ${obj}.len) + ${obj} } else { ${obj} }'
				}
				return obj
			}
			'ljust' {
				t.add_using('strings')
				if vargs.len > 0 {
					fill := if vargs.len > 1 { vargs[1] } else { "' '" }
					return 'if ${obj}.len < ${vargs[0]} { ${obj} + strings.repeat(${fill}[0], ${vargs[0]} - ${obj}.len) } else { ${obj} }'
				}
				return obj
			}
			'rjust' {
				t.add_using('strings')
				if vargs.len > 0 {
					fill := if vargs.len > 1 { vargs[1] } else { "' '" }
					return 'if ${obj}.len < ${vargs[0]} { strings.repeat(${fill}[0], ${vargs[0]} - ${obj}.len) + ${obj} } else { ${obj} }'
				}
				return obj
			}
			'center' {
				t.add_using('strings')
				if vargs.len > 0 {
					fill := if vargs.len > 1 { vargs[1] } else { "' '" }
					return 'if ${obj}.len < ${vargs[0]} { lpad := (${vargs[0]} - ${obj}.len) / 2; strings.repeat(${fill}[0], lpad) + ${obj} + strings.repeat(${fill}[0], ${vargs[0]} - ${obj}.len - lpad) } else { ${obj} }'
				}
				return obj
			}
			// List methods
			'remove' {
				if vargs.len > 0 {
					// V uses .delete() with index, not value
					// Need to find the index first
					return '${obj}.delete(${obj}.index(${vargs[0]}))'
				}
				return obj
			}
			'pop' {
				// For lists, V has .pop()
				// For dicts with a key argument, need to get value before deleting
				if vargs.len > 0 {
					// Dict pop - get value then delete
					// Note: V's delete doesn't return the value, and we can't use none
					// Use 0 as default for int maps, empty string for string maps
					return '(${obj}[${vargs[0]}] or { 0 })'
				}
				return '${obj}.pop()'
			}
			'insert' {
				if vargs.len >= 2 {
					return '${obj}.insert(${vargs[0]}, ${vargs[1]})'
				}
				return obj
			}
			'extend' {
				if vargs.len > 0 {
					return '${obj} << ${vargs[0]}'
				}
				return obj
			}
			'index' {
				// Python list.index() / str.index() raise ValueError if not found
				if vargs.len > 0 {
					return "${obj}.index(${vargs[0]}) or { panic('value not found') }"
				}
				return '0'
			}
			'copy' {
				return '${obj}.clone()'
			}
			'clear' {
				return '${obj}.clear()'
			}
			'reverse' {
				return '${obj}.reverse()'
			}
			'sort' {
				// Check for reverse=True keyword argument
				for kw in node.keywords {
					if arg := kw.arg {
						if arg == 'reverse' && t.visit_expr(kw.value) == 'true' {
							return '${obj}.sort(a > b)'
						}
					}
				}
				return '${obj}.sort(a < b)'
			}
			// Dict methods. These names are shared with user classes, so only
			// rewrite when the receiver is a known map; otherwise fall through to
			// the generic method call below and keep the user's own method.
			'keys' {
				if t.is_map_expr(attr_node.value) {
					return '${obj}.keys()'
				}
			}
			'values' {
				if t.is_map_expr(attr_node.value) {
					return '${obj}.values()'
				}
			}
			'items' {
				if t.is_map_expr(attr_node.value) {
					// V doesn't have items(), iterate directly
					return '${obj} // .items() - iterate with for k, v in dict'
				}
			}
			'get' {
				if t.is_map_expr(attr_node.value) {
					if vargs.len >= 2 {
						return '${obj}[${vargs[0]}] or { ${vargs[1]} }'
					}
					if vargs.len == 1 {
						return '${obj}[${vargs[0]}] or { none }'
					}
				}
			}
			'update' {
				if t.is_map_expr(attr_node.value) {
					if vargs.len > 0 {
						return '// ${obj}.update() - manually merge dicts'
					}
					return obj
				}
			}
			else {
				// Not a known builtin method: forward it as an ordinary V method
				// call. Falling through here used to drop the call entirely and
				// evaluate to the bare receiver.
				mut call := if vargs.len > 0 {
					'${obj}.${method}(${vargs.join(', ')})'
				} else {
					'${obj}.${method}()'
				}
				// list.append becomes the V `<<` operator.
				if method == 'append' && vargs.len > 0 {
					call = '${obj} << ${vargs[0]}'
				}
				// A qualified callee like `sys.exit` or `logging.info` is handled by
				// the builtin table further down; only treat it as a method call
				// when the receiver is a plain local.
				if attr_node.value is Name && !t.is_known_module_receiver((attr_node.value as Name).id) {
					// Calling a method with a `mut self` receiver mutates the local,
					// so the local must be declared `mut`.
					recv := (attr_node.value as Name).id
					recv_type := t.var_types[recv] or { t.infer_expr_type(attr_node.value) }
					if t.mut_receiver_methods['${recv_type}_${method}'] {
						t.extra_mut_vars[recv] = true
					}
					return call
				}
			}
		}
	}

	// Check if this is a struct constructor call (known dataclass)
	// Only a bare Name can be a constructor. `b.get()` also lands here when the
	// method table above misses, because the receiver may share a class-attr
	// symbol name; treating it as a constructor would silently drop the method.
	// A qualified name (`util.Box`) still names a struct, so look the class up by
	// its bare name while keeping the qualified spelling in the emitted literal.
	mut ctor_lookup := fname
	if dot := fname.last_index('.') {
		ctor_lookup = fname[dot + 1..]
	}
	if node.func !is Attribute && ctor_lookup in t.known_classes {
		// Keep the module qualifier: `Box{}` would refer to nothing when the
		// class lives in another V module.
		emitted_ctor := if ctor_lookup == fname {
			emitted_class_name(fname)
		} else {
			fname
		}
		mut field_vals := map[string]string{}

		// Handle keyword arguments
		for kw in node.keywords {
			if arg := kw.arg {
				if arg.len > 0 {
					field_vals[arg] = t.visit_expr(kw.value)
				}
			}
		}

		// Handle positional arguments (map to fields in order)
		fields := t.known_classes[fname]
		for i, arg in vargs {
			if i < fields.len {
				field_vals[fields[i]] = arg
			}
		}

		direct_fields := t.class_direct_fields[fname] or { fields.clone() }
		base_names := t.class_base_names[fname] or { []string{} }

		// Generate struct literal with indentation for vfmt
		mut field_parts := []string{}
		for field in direct_fields {
			if val := field_vals[field] {
				field_parts << '\t${field}: ${val}'
			}
		}
		for base_name in base_names {
			base_init := t.build_inline_class_init(base_name, field_vals)
			if base_init.len > 0 {
				field_parts << '\t${emitted_class_name(base_name)}: ${base_init}'
			}
		}
		if field_parts.len == 0 {
			return '${emitted_ctor}{}'
		}
		return '${emitted_ctor}{\n${field_parts.join('\n')}\n}'
	}

	for kw in node.keywords {
		vargs << t.visit_expr(kw.value)
	}

	// Try builtin dispatch
	result, handled := dispatch_builtin(mut t, fname, node, vargs)
	if handled {
		return result
	}

	// Handle append (which becomes <<)
	if fname.ends_with(' << ') {
		if vargs.len > 0 {
			return '${fname}${vargs[0]}'
		}
		return fname.trim_right(' ')
	}

	// Default call
	mut call_name := fname
	if should_lowercase_call_name(call_name, t.known_classes) {
		call_name = lower_first_ascii(call_name)
	}
	if vargs.len > 0 {
		return '${call_name}(${vargs.join(', ')})'
	}
	return '${call_name}()'
}

fn (mut t VTranspiler) build_inline_class_init(class_name string, field_vals map[string]string) string {
	emitted_name := emitted_class_name(class_name)
	mut parts := []string{}
	direct_fields := t.class_direct_fields[class_name] or { []string{} }
	for field in direct_fields {
		if val := field_vals[field] {
			parts << '${field}: ${val}'
		}
	}
	base_names := t.class_base_names[class_name] or { []string{} }
	for base_name in base_names {
		base_init := t.build_inline_class_init(base_name, field_vals)
		if base_init != '' {
			parts << '${emitted_class_name(base_name)}: ${base_init}'
		}
	}
	if parts.len == 0 {
		return ''
	}
	return '${emitted_name}{${parts.join(', ')}}'
}

fn (mut t VTranspiler) resolve_super_base() string {
	if t.current_class_name == '' {
		return ''
	}
	bases := t.class_base_names[t.current_class_name] or { []string{} }
	if bases.len == 0 {
		return ''
	}
	base := bases[0]
	// Python builtins like Exception are not modeled as embedded structs in V.
	if base !in t.known_classes {
		return ''
	}
	return emitted_class_name(base)
}

// collect_super_calls returns the method names invoked through a `super()` call
// anywhere in the statement list.
fn collect_super_calls(stmts []Stmt) []string {
	mut names := []string{}
	for stmt in stmts {
		collect_super_calls_in_stmt(stmt, mut names)
	}
	return names
}

fn collect_super_calls_in_stmt(stmt Stmt, mut names []string) {
	match stmt {
		ExprStmt {
			collect_super_calls_in_expr((stmt as ExprStmt).value, mut names)
		}
		Return {
			if ret := (stmt as Return).value {
				collect_super_calls_in_expr(ret, mut names)
			}
		}
		Assign {
			collect_super_calls_in_expr((stmt as Assign).value, mut names)
		}
		AugAssign {
			collect_super_calls_in_expr((stmt as AugAssign).value, mut names)
		}
		AnnAssign {
			if v := (stmt as AnnAssign).value {
				collect_super_calls_in_expr(v, mut names)
			}
		}
		If {
			for s in (stmt as If).body {
				collect_super_calls_in_stmt(s, mut names)
			}
			for s in (stmt as If).orelse {
				collect_super_calls_in_stmt(s, mut names)
			}
		}
		For {
			for s in (stmt as For).body {
				collect_super_calls_in_stmt(s, mut names)
			}
		}
		While {
			for s in (stmt as While).body {
				collect_super_calls_in_stmt(s, mut names)
			}
		}
		With {
			for s in (stmt as With).body {
				collect_super_calls_in_stmt(s, mut names)
			}
		}
		Try {
			for s in (stmt as Try).body {
				collect_super_calls_in_stmt(s, mut names)
			}
		}
		else {}
	}
}

fn collect_super_calls_in_expr(expr Expr, mut names []string) {
	match expr {
		Call {
			c := expr as Call
			if c.func is Attribute {
				attr := c.func as Attribute
				if attr.value is Call {
					inner := attr.value as Call
					if inner.func is Name && (inner.func as Name).id == 'super' {
						append_unique_strings(mut names, [attr.attr])
					}
				}
			}
			for a in c.args {
				collect_super_calls_in_expr(a, mut names)
			}
			for kw in c.keywords {
				collect_super_calls_in_expr(kw.value, mut names)
			}
		}
		Attribute {
			collect_super_calls_in_expr((expr as Attribute).value, mut names)
		}
		BinOp {
			collect_super_calls_in_expr((expr as BinOp).left, mut names)
			collect_super_calls_in_expr((expr as BinOp).right, mut names)
		}
		UnaryOp {
			collect_super_calls_in_expr((expr as UnaryOp).operand, mut names)
		}
		BoolOp {
			for v in (expr as BoolOp).values {
				collect_super_calls_in_expr(v, mut names)
			}
		}
		Compare {
			collect_super_calls_in_expr((expr as Compare).left, mut names)
			for c in (expr as Compare).comparators {
				collect_super_calls_in_expr(c, mut names)
			}
		}
		IfExp {
			collect_super_calls_in_expr((expr as IfExp).body, mut names)
			collect_super_calls_in_expr((expr as IfExp).orelse, mut names)
		}
		Await {
			collect_super_calls_in_expr((expr as Await).value, mut names)
		}
		NamedExpr {
			collect_super_calls_in_expr((expr as NamedExpr).value, mut names)
		}
		Subscript {
			collect_super_calls_in_expr((expr as Subscript).value, mut names)
		}
		Starred {
			collect_super_calls_in_expr((expr as Starred).value, mut names)
		}
		else {}
	}
}

fn should_emit_ref_field_type(typ string) bool {
	if typ == '' || typ[0] == `&` {
		return false
	}
	if typ.starts_with('[]') || typ.starts_with('map[') || typ.starts_with('?') {
		return false
	}
	return typ[0] >= `A` && typ[0] <= `Z` && typ != 'Any'
}

fn to_symbol_ident(name string) string {
	if name == '' {
		return 'v'
	}
	mut out := []u8{}
	mut prev_sep := true
	mut prev_input_upper := false
	for i := 0; i < name.len; i++ {
		c := name[i]
		is_upper := c >= `A` && c <= `Z`
		is_lower := c >= `a` && c <= `z`
		is_digit := c >= `0` && c <= `9`
		if is_upper {
			if out.len > 0 && !prev_sep && ((out[out.len - 1] >= `a` && out[out.len - 1] <= `z`)
				|| (out[out.len - 1] >= `0` && out[out.len - 1] <= `9`)) && !prev_input_upper {
				out << `_`
			}
			out << (c + 32)
			prev_sep = false
			prev_input_upper = true
		} else if is_lower || is_digit {
			out << c
			prev_sep = false
			prev_input_upper = false
		} else if !prev_sep {
			out << `_`
			prev_sep = true
			prev_input_upper = false
		}
	}
	mut cleaned := out.bytestr().trim('_')
	if cleaned == '' {
		return 'v'
	}
	if cleaned[0] >= `0` && cleaned[0] <= `9` {
		cleaned = 'v_${cleaned}'
	}
	return cleaned
}

fn class_attr_symbol_name(class_name string, attr_name string) string {
	return '${to_symbol_ident(class_name)}_${to_symbol_ident(attr_name)}'
}

fn is_v_field_ident(name string) bool {
	if name == '' {
		return false
	}
	first := name[0]
	if !((first >= `a` && first <= `z`) || first == `_`) {
		return false
	}
	for c in name[1..].bytes() {
		is_lower := c >= `a` && c <= `z`
		is_digit := c >= `0` && c <= `9`
		if !(is_lower || is_digit || c == `_`) {
			return false
		}
	}
	return true
}

fn should_lowercase_call_name(name string, known map[string][]string) bool {
	if name == '' {
		return false
	}
	if name in known {
		return false
	}
	if name.contains('.') {
		return false
	}
	c := name[0]
	return c >= `A` && c <= `Z`
}

fn lower_first_ascii(name string) string {
	if name == '' {
		return name
	}
	first := name[0]
	if first >= `A` && first <= `Z` {
		return (first + 32).ascii_str() + name[1..]
	}
	return name
}

// visit_attribute emits V code for attribute access (Attribute).
pub fn (mut t VTranspiler) visit_attribute(node Attribute) string {
	if node.value is Name {
		class_name := (node.value as Name).id
		if class_attrs := t.class_attr_symbols[class_name] {
			if sym := class_attrs[node.attr] {
				return sym
			}
		}
	}

	value := t.visit_expr(node.value)
	mut attr := node.attr
	// Struct fields and locals are declared under their escaped V spelling, so an
	// access to `self._foo` must use the same escape the declaration used.
	if t.current_class_name != '' {
		if escapes := t.class_field_escapes[t.current_class_name] {
			if v_attr := escapes[attr] {
				attr = v_attr
			}
		}
	}
	// Dunder methods are emitted under a different name, so `self.__int__()`
	// must call the method as declared.
	attr = python_dunder_method_names[attr] or { attr }
	attr_path := '${value}.${attr}'

	// Try attribute dispatch
	result, handled := dispatch_attr(mut t, attr_path)
	if handled {
		return result
	}

	// Check for list.append -> <<
	if attr == 'append' {
		return '${value} << '
	}

	return '${value}.${attr}'
}

// visit_subscript emits V code for subscript access (Subscript).
pub fn (mut t VTranspiler) visit_subscript(node Subscript) string {
	value := t.visit_expr(node.value)

	if node.is_annotation {
		index := t.visit_expr(node.slice)
		mapped := v_container_type_map[value] or { value }
		if value == 'Tuple' {
			return '(${index})'
		}
		return '${mapped}[${index}]'
	}

	// Handle negative indexing - V doesn't support negative indices
	if node.slice is UnaryOp {
		unary := node.slice as UnaryOp
		if unary.op is USub {
			if unary.operand is Constant {
				c := unary.operand as Constant
				if c.value is int {
					// Convert arr[-n] to arr[arr.len - n]
					n := c.value as int
					return '${value}[${value}.len - ${n}]'
				}
			}
		}
	}

	// Handle slice with potential negative indices
	if node.slice is Slice {
		slice_node := node.slice as Slice
		mut lower := ''
		mut upper := ''

		// Handle lower bound
		if l := slice_node.lower {
			if l is UnaryOp {
				unary := l as UnaryOp
				if unary.op is USub {
					if unary.operand is Constant {
						c := unary.operand as Constant
						if c.value is int {
							n := c.value as int
							lower = '${value}.len - ${n}'
						} else {
							lower = t.visit_expr(l)
						}
					} else {
						lower = t.visit_expr(l)
					}
				} else {
					lower = t.visit_expr(l)
				}
			} else {
				lower = t.visit_expr(l)
			}
		}

		// Handle upper bound
		if u := slice_node.upper {
			if u is UnaryOp {
				unary := u as UnaryOp
				if unary.op is USub {
					if unary.operand is Constant {
						c := unary.operand as Constant
						if c.value is int {
							n := c.value as int
							upper = '${value}.len - ${n}'
						} else {
							upper = t.visit_expr(u)
						}
					} else {
						upper = t.visit_expr(u)
					}
				} else {
					upper = t.visit_expr(u)
				}
			} else {
				upper = t.visit_expr(u)
			}
		}

		return '${value}[${lower}..${upper}]'
	}

	index := t.visit_expr(node.slice)
	return '${value}[${index}]'
}

// visit_slice emits V code for slices (Slice).
pub fn (mut t VTranspiler) visit_slice(node Slice) string {
	lower := if l := node.lower { t.visit_expr(l) } else { '' }
	upper := if u := node.upper { t.visit_expr(u) } else { '' }
	return '${lower}..${upper}'
}

// visit_list emits V code for list literals (List).
pub fn (mut t VTranspiler) visit_list(node List) string {
	// Check for starred elements
	has_starred := node.elts.any(fn (e Expr) bool {
		return e is Starred
	})

	if has_starred {
		mut parts := []string{}
		mut curr_list := []string{}

		for e in node.elts {
			if e is Starred {
				if curr_list.len > 0 {
					parts << '[${curr_list.join(', ')}]'
					curr_list = []
				}
				parts << t.visit_expr((e as Starred).value)
			} else {
				curr_list << t.visit_expr(e)
			}
		}

		if curr_list.len > 0 {
			parts << '[${curr_list.join(', ')}]'
		}

		if parts.len == 0 {
			return '[]'
		}

		mut result := parts[0]
		if !result.starts_with('[') {
			result = '([]).concat(${result})'
		}
		for i := 1; i < parts.len; i++ {
			result = '(${result}).concat(${parts[i]})'
		}
		return result
	}

	mut elts := []string{}
	for e in node.elts {
		elts << t.visit_expr(e)
	}
	flat := '[${elts.join(', ')}]'
	if flat.len <= max_generated_line_len {
		return flat
	}
	mut lines := []string{}
	lines << '['
	for e in elts {
		lines << '\t${e},'
	}
	lines << ']'
	return lines.join('\n')
}

// visit_tuple (same as List in V)
pub fn (mut t VTranspiler) visit_tuple(node Tuple) string {
	// Check for starred elements
	has_starred := node.elts.any(fn (e Expr) bool {
		return e is Starred
	})

	if has_starred {
		// Same logic as list
		mut parts := []string{}
		mut curr_list := []string{}

		for e in node.elts {
			if e is Starred {
				if curr_list.len > 0 {
					parts << '[${curr_list.join(', ')}]'
					curr_list = []
				}
				parts << t.visit_expr((e as Starred).value)
			} else {
				curr_list << t.visit_expr(e)
			}
		}

		if curr_list.len > 0 {
			parts << '[${curr_list.join(', ')}]'
		}

		if parts.len == 0 {
			return '[]'
		}

		mut result := parts[0]
		if !result.starts_with('[') {
			result = '([]).concat(${result})'
		}
		for i := 1; i < parts.len; i++ {
			result = '(${result}).concat(${parts[i]})'
		}
		return result
	}

	mut elts := []string{}
	for e in node.elts {
		elts << t.visit_expr(e)
	}
	return '[${elts.join(', ')}]'
}

// visit_dict emits V code for dict literals (Dict).
pub fn (mut t VTranspiler) visit_dict(node Dict) string {
	mut pairs := []string{}
	for i, key_opt in node.keys {
		if key := key_opt {
			k := t.visit_expr(key)
			v := t.visit_expr(node.values[i])
			pairs << '\t${k}: ${v}'
		}
	}
	if pairs.len == 0 {
		// V has no untyped empty map literal; fall back to a string-keyed map,
		// which is what Python code almost always means for `{}`.
		t.generated_code_has_any_type = true
		return 'map[string]Any{}'
	}
	return '{\n${pairs.join('\n')}\n}'
}

// visit_set (same as List in V)
pub fn (mut t VTranspiler) visit_set(node Set) string {
	mut elts := []string{}
	for e in node.elts {
		elts << t.visit_expr(e)
	}
	return '[${elts.join(', ')}]'
}

// visit_ifexp emits V code for inline if-expressions (IfExp).
pub fn (mut t VTranspiler) visit_ifexp(node IfExp) string {
	test := t.visit_expr(node.test)
	body := t.visit_expr(node.body)
	orelse := t.visit_expr(node.orelse)
	return 'if ${test} { ${body} } else { ${orelse} }'
}

// visit_lambda emits V code for lambda expressions (Lambda).
pub fn (mut t VTranspiler) visit_lambda(node Lambda) string {
	mut args := []string{}

	// Try to infer types from the body expression
	// If body uses arithmetic, use int; otherwise use generic default
	body := t.visit_expr(node.body)
	stripped_body := strip_outer_parens(body)

	// Check if body contains arithmetic operations
	body_has_arithmetic := body.contains(' + ') || body.contains(' - ') || body.contains(' * ')
		|| body.contains(' / ')

	lambda_type := if body_has_arithmetic { 'int' } else { 'string' }

	for arg in node.args.args {
		name := escape_identifier(arg.arg)
		// Track identifiers escaped due to built-in type name conflicts
		if arg.arg in v_builtin_types {
			t.escaped_identifiers[arg.arg] = true
		}
		// V requires type annotations on each parameter
		// Use annotation if available, otherwise default based on body analysis
		if ann := arg.annotation {
			type_str := t.typename_from_annotation(ann)
			args << '${name} ${type_str}'
		} else {
			// Use _ for unused parameters (starts with underscore)
			if name.starts_with('_') && name != '_' {
				args << '_ ${lambda_type}'
			} else {
				args << '${name} ${lambda_type}'
			}
		}
	}

	return 'fn (${args.join(', ')}) ${lambda_type} {\n\treturn ${stripped_body}\n}'
}

// visit_list_comp emits V code for list comprehensions (ListComp).
pub fn (mut t VTranspiler) visit_list_comp(node ListComp) string {
	// Should be transformed by VComprehensionRewriter
	// Fallback implementation
	return t.visit_generator_exp_impl(node.elt, node.generators)
}

// visit_set_comp emits V code for set comprehensions (SetComp).
pub fn (mut t VTranspiler) visit_set_comp(node SetComp) string {
	return t.visit_generator_exp_impl(node.elt, node.generators)
}

// visit_dict_comp emits V code for dict comprehensions (DictComp).
pub fn (mut t VTranspiler) visit_dict_comp(node DictComp) string {
	mut buf := []string{}

	// Pre-bind comprehension loop variables so key/value type inference works.
	mut bound_vars := []string{}
	for comp in node.generators {
		elem_type := t.infer_iter_elem_type(comp.iter)
		if elem_type.len > 0 && comp.target is Name {
			vname := (comp.target as Name).id
			t.var_types[vname] = elem_type
			bound_vars << vname
		}
	}

	// Infer key and value types from the key/value expressions
	key_type := t.infer_expr_type(node.key)
	val_type := t.infer_expr_type(node.value)
	k := if key_type.len > 0 { key_type } else { 'string' }
	v := if val_type.len > 0 { val_type } else { 'Any' }
	if v == 'Any' {
		t.generated_code_has_any_type = true
	}
	mtype := 'map[${k}]${v}'

	buf << '(fn () ${mtype} {'
	buf << 'mut result := ${mtype}{}'

	for comp in node.generators {
		target := t.visit_expr(comp.target)
		iter := t.visit_expr(comp.iter)
		buf << 'for ${target} in ${iter} {'

		for if_clause in comp.ifs {
			buf << 'if ${t.visit_expr(if_clause)} {'
		}

		key := t.visit_expr(node.key)
		value := t.visit_expr(node.value)
		buf << 'result[${key}] = ${value}'

		for _ in comp.ifs {
			buf << '}'
		}

		buf << '}'
	}

	buf << 'return result'
	buf << '}())'

	// Clean up bound vars
	for vname in bound_vars {
		t.var_types.delete(vname)
	}

	return buf.join('\n')
}

// visit_generator_exp emits V code for generator expressions (GeneratorExp).
pub fn (mut t VTranspiler) visit_generator_exp(node GeneratorExp) string {
	return t.visit_generator_exp_impl(node.elt, node.generators)
}

fn (mut t VTranspiler) visit_generator_exp_impl(elt Expr, generators []Comprehension) string {
	if generators.len == 0 {
		return '[]'
	}

	// If any if-clause in any generator contains a walrus (NamedExpr), expand to
	// an IIFE for-loop so V's type-safe closures are not required.
	for gen in generators {
		for if_clause in gen.ifs {
			if has_walrus_in_expr(if_clause) {
				return t.visit_generator_exp_impl_walrus(elt, generators)
			}
		}
	}

	// Check if the iter is a range() call - need special handling
	mut result := ''
	iter := generators[0].iter
	target := t.visit_expr(generators[0].target)

	if iter is Call {
		call := iter as Call
		if call.func is Name {
			fname := (call.func as Name).id
			if fname == 'range' {
				// Handle range() specially - convert to array
				if call.args.len == 1 {
					end := t.visit_expr(call.args[0])
					result = '[]int{len: ${end}, init: index}'
				} else if call.args.len == 2 {
					start := t.visit_expr(call.args[0])
					end := t.visit_expr(call.args[1])
					result = '[]int{len: ${end} - ${start}, init: index + ${start}}'
				} else if call.args.len == 3 {
					start := t.visit_expr(call.args[0])
					end := t.visit_expr(call.args[1])
					step := t.visit_expr(call.args[2])
					_ = step
					result = '[]int{len: ${end} - ${start}, init: index + ${start}}'
				} else {
					result = t.visit_expr(iter)
				}
			} else {
				result = t.visit_expr(iter)
			}
		} else {
			result = t.visit_expr(iter)
		}
	} else {
		result = t.visit_expr(iter)
	}

	// Apply filters - need to use 'it' for the element reference
	for if_clause in generators[0].ifs {
		mut filter_expr := t.visit_expr(if_clause)
		// Replace target variable with 'it' for filter lambda
		filter_expr = filter_expr.replace(target, 'it')
		result = '${result}.filter(${filter_expr})'
	}

	// Apply map - need to use 'it' for the element reference
	mut map_expr := t.visit_expr(elt)
	// Replace target variable with 'it' for map lambda
	map_expr = map_expr.replace(target, 'it')
	result = '${result}.map(${map_expr})'

	return result
}

// visit_await emits V code for await expressions (Await).
pub fn (mut t VTranspiler) visit_await(node Await) string {
	// Unwrap common asyncio wrappers when they are directly awaited.
	if node.value is Call {
		call := node.value as Call
		if call.func is Attribute {
			func_attr := call.func as Attribute
			owner := t.visit_expr(func_attr.value)
			if owner == 'asyncio' {
				if func_attr.attr == 'run' && call.args.len > 0 {
					return t.visit_expr(call.args[0])
				}
				if func_attr.attr == 'create_task' && call.args.len > 0 {
					// await asyncio.create_task(f()) -> f()
					return t.visit_expr(call.args[0])
				}
			}
		}
	}

	// If frontend inference marked this name as a channel, lower await to receive.
	if node.value is Name {
		name := node.value as Name
		if typ := t.var_types[name.id] {
			if typ.starts_with('chan') {
				return '<-${t.visit_expr(node.value)}'
			}
		}
	}

	// Default await lowering remains a direct expression pass-through.
	return t.visit_expr(node.value)
}

// visit_yield emits V code for yield expressions (Yield).
pub fn (mut t VTranspiler) visit_yield(node Yield) string {
	if val := node.value {
		return 'ch <- ${t.visit_expr(val)}'
	}
	return 'ch <- 0'
}

// visit_yield_from emits V code for yield-from expressions (YieldFrom).
pub fn (mut t VTranspiler) visit_yield_from(node YieldFrom) string {
	gen_expr := t.visit_expr(node.value)
	gen_var := t.new_tmp('gen')

	mut buf := []string{}
	buf << '${gen_var} := ${gen_expr}'
	buf << '// yield from ${gen_var}'
	buf << 'for {'
	buf << '    val := <-${gen_var} or { break }'
	buf << '    ch <- val'
	buf << '}'

	return buf.join('\n')
}

// visit_formatted_value emits a bare `${expr}` interpolation segment.
// Only called directly when a FormattedValue appears outside a JoinedStr context.
pub fn (mut t VTranspiler) visit_formatted_value(node FormattedValue) string {
	expr := t.visit_expr(node.value)
	return "'\${${expr}}'"
}

// fmtval_segment returns the inner interpolation text for one FormattedValue
// node, to be embedded inside a surrounding single-quoted V string.
fn (mut t VTranspiler) fmtval_segment(node FormattedValue) string {
	expr := t.visit_expr(node.value)
	return '\${${expr}}'
}

// visit_joined_str emits V code for an f-string (JoinedStr) as a single
// V interpolated string literal `'...${expr}...'`.
pub fn (mut t VTranspiler) visit_joined_str(node JoinedStr) string {
	if node.values.len == 0 {
		return "''"
	}
	mut inner := ''
	mut use_double := false
	for val in node.values {
		match val {
			Constant {
				if val.value is string {
					s := val.value as string
					// Escape special chars; protect `${` from being treated as
					// interpolation. A literal `'` cannot be backslash-escaped in a
					// V single-quoted string, so use a double-quoted literal instead.
					if s.contains("'") && !s.contains('"') {
						use_double = true
					}
					mut piece := escape_interp_string(s)
					if use_double {
						// In a double-quoted V string `\'` is an invalid escape.
						piece = piece.replace("\\'", "'")
					}
					inner += piece
				}
			}
			FormattedValue {
				inner += t.fmtval_segment(val)
			}
			else {
				// Nested JoinedStr or other node — fall back to expr
				inner += '\${${t.visit_expr(val)}}'
			}
		}
	}
	if use_double {
		return '"' + inner + '"'
	}
	return "'${inner}'"
}

// visit_named_expr handles NamedExpr (walrus operator) usage.
// When used standalone, just emit as assignment expression.
pub fn (mut t VTranspiler) visit_named_expr(node NamedExpr) string {
	target := t.visit_expr(node.target)
	value := t.visit_expr(node.value)
	return '(${target} := ${value})'
}

// has_walrus_in_compare checks if a Compare expression has a NamedExpr (walrus) as its left operand
fn has_walrus_in_compare(test Expr) bool {
	if test is Compare {
		cmp := test as Compare
		if cmp.left is NamedExpr {
			return true
		}
	}
	return false
}

// has_walrus_in_expr recursively checks whether an expression contains a NamedExpr (walrus).
fn has_walrus_in_expr(e Expr) bool {
	match e {
		NamedExpr {
			return true
		}
		Compare {
			if has_walrus_in_expr(e.left) {
				return true
			}
			for c in e.comparators {
				if has_walrus_in_expr(c) {
					return true
				}
			}
		}
		BoolOp {
			for v in e.values {
				if has_walrus_in_expr(v) {
					return true
				}
			}
		}
		BinOp {
			if has_walrus_in_expr(e.left) || has_walrus_in_expr(e.right) {
				return true
			}
		}
		UnaryOp {
			if has_walrus_in_expr(e.operand) {
				return true
			}
		}
		Call {
			for a in e.args {
				if has_walrus_in_expr(a) {
					return true
				}
			}
		}
		else {}
	}

	return false
}

// collect_walrus_assigns extracts all NamedExpr assignments from an expression tree.
// Returns list of "target := value" strings (assignments) in encounter order.
// After extraction, replaces each NamedExpr occurrence with the target identifier.
fn (mut t VTranspiler) collect_walrus_assigns(e Expr) ([]string, string) {
	mut assigns := []string{}
	rendered := t.extract_walrus_from_expr(e, mut assigns)
	return assigns, rendered
}

// extract_walrus_from_expr recursively visits an expression, pulling out NamedExpr nodes
// as hoisted assignments and replacing them with their target names.
fn (mut t VTranspiler) extract_walrus_from_expr(e Expr, mut assigns []string) string {
	match e {
		NamedExpr {
			tgt := t.visit_expr(e.target)
			val := t.visit_expr(e.value)
			assigns << '${tgt} := ${val}'
			return tgt
		}
		BinOp {
			// Recurse into both sides so walrus nested in e.g. `(x := f()) % 4` is hoisted
			left_str := t.extract_walrus_from_expr(e.left, mut assigns)
			right_str := t.extract_walrus_from_expr(e.right, mut assigns)
			op_sym := op_to_symbol(e.op.type_name())
			return '${left_str} ${op_sym} ${right_str}'
		}
		Compare {
			left_str := t.extract_walrus_from_expr(e.left, mut assigns)
			mut parts := [left_str]
			for i, op in e.ops {
				sym := op_to_symbol(get_cmp_op_type(op))
				rhs := t.extract_walrus_from_expr(e.comparators[i], mut assigns)
				parts << '${sym} ${rhs}'
			}
			return parts.join(' ')
		}
		BoolOp {
			op_sym := if e.op is And { '&&' } else { '||' }
			mut parts := []string{}
			for v in e.values {
				parts << t.extract_walrus_from_expr(v, mut assigns)
			}
			return parts.join(' ${op_sym} ')
		}
		UnaryOp {
			op_sym := match e.op {
				Invert { 'Invert' }
				Not { 'Not' }
				UAdd { 'UAdd' }
				USub { 'USub' }
			}

			operand_str := t.extract_walrus_from_expr(e.operand, mut assigns)
			return '${op_sym}${operand_str}'
		}
		else {
			return t.visit_expr(e)
		}
	}
}

// visit_generator_exp_impl_walrus expands a comprehension with walrus in its filters
// to an IIFE for-loop so V's type-safe closures are not required.
fn (mut t VTranspiler) visit_generator_exp_impl_walrus(elt Expr, generators []Comprehension) string {
	// Determine element type for result array
	elem_type := t.infer_expr_type(elt)
	arr_type := if elem_type.len > 0 && elem_type != 'Any' {
		'[]${elem_type}'
	} else {
		t.generated_code_has_any_type = true
		'[]Any'
	}

	tab := '\t'
	mut lines := ['(fn () ${arr_type} {']
	lines << '${tab}mut result := ${arr_type}{}'

	// Track nesting depth; each generator adds a for-loop level.
	mut depth := 1
	mut close_braces := 0 // total extra braces to close after element emit

	for comp in generators {
		indent_ := tab.repeat(depth)
		target_str := t.visit_expr(comp.target)

		// Determine iteration expression (use range notation for range() calls)
		mut for_expr := t.visit_expr(comp.iter)
		if comp.iter is Call {
			call := comp.iter as Call
			if call.func is Name && (call.func as Name).id == 'range' {
				if call.args.len == 1 {
					end := t.visit_expr(call.args[0])
					for_expr = '0..${end}'
				} else if call.args.len == 2 {
					start := t.visit_expr(call.args[0])
					end := t.visit_expr(call.args[1])
					for_expr = '${start}..${end}'
				} else if call.args.len == 3 {
					start := t.visit_expr(call.args[0])
					end := t.visit_expr(call.args[1])
					step := t.visit_expr(call.args[2])
					_ = step
					for_expr = '${start}..${end}'
				}
			}
		}

		lines << '${indent_}for ${target_str} in ${for_expr} {'
		depth++
		close_braces++

		// Emit if-clauses nested inside this for loop
		for if_clause in comp.ifs {
			if_indent := tab.repeat(depth)
			if has_walrus_in_expr(if_clause) {
				mut walrus_assigns := []string{}
				cond_str := t.extract_walrus_from_expr(if_clause, mut walrus_assigns)
				for wa in walrus_assigns {
					lines << '${if_indent}${wa}'
				}
				lines << '${if_indent}if ${cond_str} {'
			} else {
				lines << '${if_indent}if ${t.visit_expr(if_clause)} {'
			}
			depth++
			close_braces++
		}
	}

	// Emit the result element at current depth
	elem_indent := tab.repeat(depth)
	elem_str := t.visit_expr(elt)
	lines << '${elem_indent}result << ${elem_str}'

	// Close all opened braces
	for i := close_braces; i > 0; i-- {
		lines << '${tab.repeat(i)}}'
	}

	lines << '${tab}return result'
	lines << '})()'
	return lines.join('\n')
}

// extract_walrus_parts handles assignment and modified test from a Compare with NamedExpr
// Returns [assign_line, new_test]
fn (mut t VTranspiler) extract_walrus_parts(test Expr) []string {
	if test is Compare {
		cmp := test as Compare
		if cmp.left is NamedExpr {
			ne := cmp.left as NamedExpr
			target := t.visit_expr(ne.target)
			value := t.visit_expr(ne.value)
			assign_line := '${target} := ${value}'
			// Rebuild Compare without NamedExpr: target op comparator
			op := op_to_symbol(get_cmp_op_type(cmp.ops[0]))
			right := t.visit_expr(cmp.comparators[0])
			new_test := '${target} ${op} ${right}'
			return [assign_line, new_test]
		}
	}
	return []string{}
}

// visit_starred emits V code for starred expressions (Starred).
pub fn (mut t VTranspiler) visit_starred(node Starred) string {
	return '...${t.visit_expr(node.value)}'
}

// typename_from_annotation extracts a typename string from an annotation expression.
// Accept an optional annotation (`?Expr`) so callers that hold optional
// annotation fields (e.g., `Arg.annotation ?Expr`) can pass them directly
// without causing Option/Expr mismatches during codegen.
pub fn (mut t VTranspiler) typename_from_annotation(ann ?Expr) string {
	// If no annotation was provided, return empty string to indicate
	// "no annotation" (callers often treat empty as missing and use
	// fallbacks). This avoids assigning a concrete default type where
	// the caller may prefer to apply other inference heuristics.
	a := ann or { return '' }

	match a {
		Name {
			name := a.id
			if name in v_type_map {
				return v_type_map[name]
			}
			return name
		}
		Subscript {
			value := t.typename_from_annotation(a.value)

			// Union[A, B, ...] → V named sum type comment; inline use emits first type
			// with a note. When used as a parameter annotation we emit a comment.
			if value == 'Union' {
				// Collect all union members from the slice
				mut members := []string{}
				if a.slice is Tuple {
					for e in (a.slice as Tuple).elts {
						members << t.typename_from_annotation(e)
					}
				} else {
					members << t.typename_from_annotation(a.slice)
				}
				// Check for Optional pattern: Union[X, None]
				if members.len == 2 && members[1] == 'none' {
					return '?${map_type(members[0])}'
				}
				if members.len == 2 && members[0] == 'none' {
					return '?${map_type(members[1])}'
				}
				// General multi-type union — V requires a named sum type.
				// Return Any (compiles cleanly); store a hint comment for the caller.
				t.generated_code_has_any_type = true
				union_str := members.join(' | ')
				t.pending_type_notes << '// NOTE: Union[${members.join(', ')}] — define: type X = ${union_str}'
				return 'Any'
			}

			// Optional[X] → ?X
			if value == 'Optional' {
				inner := t.typename_from_annotation(a.slice)
				return '?${map_type(inner)}'
			}

			// Callable[[A, B], R] → fn(A, B) R
			if value == 'Callable' {
				if a.slice is Tuple {
					elts := (a.slice as Tuple).elts
					if elts.len == 2 {
						mut param_types := []string{}
						if elts[0] is List {
							for pe in (elts[0] as List).elts {
								param_types << t.typename_from_annotation(pe)
							}
						} else {
							param_types << t.typename_from_annotation(elts[0])
						}
						ret_type := t.typename_from_annotation(elts[1])
						if ret_type == '' || ret_type == 'None' || ret_type == 'none' {
							return 'fn (${param_types.join(', ')})'
						}
						return 'fn (${param_types.join(', ')}) ${ret_type}'
					}
				}
				return 'fn (Any) Any'
			}

			index := t.typename_from_annotation(a.slice)

			mapped := v_container_type_map[value] or { value }
			// `value` has already been mapped through the container table, so the
			// raw subscript name is needed to recognise `Tuple`/`tuple`.
			base := a.value
			base_name := if base is Name { (base as Name).id } else { value }
			if base_name == 'Tuple' || base_name == 'tuple' {
				// Collect individual element types from the slice.
				mut elem_types := []string{}
				if a.slice is Tuple {
					for e in (a.slice as Tuple).elts {
						// Ignore trailing Ellipsis (variable-length hint)
						if e is Constant && (e as Constant).value is EllipsisValue {
							continue
						}
						elem_types << t.typename_from_annotation(e)
					}
				} else {
					elem_types << index
				}
				if elem_types.len == 0 {
					return '[]Any'
				}
				// Tuple[T, ...] — variable-length homogeneous sequence → []T
				if a.slice is Tuple {
					raw_elts := (a.slice as Tuple).elts
					has_ellipsis := raw_elts.any(it is Constant
						&& (it as Constant).value is EllipsisValue)
					if has_ellipsis && elem_types.len == 1 {
						return '[]${map_type(elem_types[0])}'
					}
				}
				// Uniform types → fixed-size array [N]T
				first_et := elem_types[0]
				all_same := elem_types.all(it == first_et)
				if all_same {
					mapped_et := map_type(first_et)
					return '[${elem_types.len}]${mapped_et}'
				}
				// Mixed types — no direct V equivalent; emit []Any with a hint.
				t.generated_code_has_any_type = true
				joined := elem_types.join(', ')
				t.pending_type_notes << '// NOTE: Tuple[${joined}] — define a struct with named fields'
				return '[]Any'
			}
			if base_name == 'Literal' {
				// Literal[v1, v2, ...] — extract the common value type and emit it.
				mut lit_types := []string{}
				if a.slice is Tuple {
					for e in (a.slice as Tuple).elts {
						lit_types << t.typename_from_annotation(e)
					}
				} else {
					lit_types << index
				}
				// Deduplicate
				mut seen := map[string]bool{}
				mut unique := []string{}
				for lt in lit_types {
					if lt !in seen {
						seen[lt] = true
						unique << lt
					}
				}
				base_type := if unique.len == 1 { map_type(unique[0]) } else { 'Any' }
				if unique.len > 1 {
					t.generated_code_has_any_type = true
				}
				t.pending_type_notes << '// NOTE: Literal[${index}] — allowed values are ${index}'
				return base_type
			}
			if base_name == 'Dict' || base_name == 'dict' {
				// Dict[K, V] — V spells this map[K]V, with no comma. The slice is
				// a Tuple of two elements, so recurse over each separately.
				if a.slice is Tuple {
					kvs := (a.slice as Tuple).elts
					if kvs.len == 2 {
						k := t.typename_from_annotation(kvs[0])
						v := t.typename_from_annotation(kvs[1])
						return 'map[${k}]${v}'
					}
				}
				return 'map[${index}]'
			}
			// User-defined generic (e.g. Stack[T]) — emit Name[T] style only when
			// the base type is a user class name (PascalCase/UpperCase start) and the
			// index is a real type name, not a numeric literal mapped to Any.
			if mapped == value && value.len > 0 && value[0].is_capital() && index.len > 0
				&& index != 'Any' && index[0].is_letter() {
				return '${mapped}[${index}]'
			}
			return '${mapped}${index}'
		}
		Tuple {
			mut types := []string{}
			for e in a.elts {
				types << t.typename_from_annotation(e)
			}
			return types.join(', ')
		}
		Attribute {
			// Handle typing.X or similar qualified names
			// e.g., typing.List -> List
			attr := a.attr
			if attr in v_type_map {
				return v_type_map[attr]
			}
			if attr in v_container_type_map {
				return v_container_type_map[attr]
			}
			return attr
		}
		BinOp {
			// PEP 604: X | None -> ?X
			if a.op is BitOr {
				left := t.typename_from_annotation(a.left)
				right := t.typename_from_annotation(a.right)
				// X | None -> ?X
				if a.right is Constant {
					r := a.right as Constant
					if r.value is NoneValue {
						return '?${map_type(left)}'
					}
				}
				// None | X -> ?X
				if a.left is Constant {
					l := a.left as Constant
					if l.value is NoneValue {
						return '?${map_type(right)}'
					}
				}
				// General union: V needs a named sum type; emit Any with a hint.
				t.generated_code_has_any_type = true
				l := map_type(left)
				r := map_type(right)
				t.pending_type_notes << '// NOTE: ${l} | ${r} — define: type X = ${l} | ${r}'
				return 'Any'
			}
			return default_type
		}
		Constant {
			if a.value is string {
				s := a.value as string
				// Forward-reference string annotations like 'MyClass'
				if s == 'None' {
					return ''
				}
				return s
			}
			if a.value is NoneValue {
				return '' // None annotation → void return (no return type in V)
			}
			return default_type
		}
		else {
			return default_type
		}
	}
}

// infer_generator_yield_type walks body stmts to find Yield expressions and
// returns their unified type, falling back to 'Any'.
fn (mut t VTranspiler) infer_generator_yield_type(body []Stmt) string {
	mut types := []string{}
	t.collect_yield_types(body, mut types)
	if types.len == 0 {
		return 'Any'
	}
	// Use first type; if all are the same, return it
	first := types[0]
	for ty in types {
		if ty != first {
			return 'Any'
		}
	}
	return first
}

// collect_yield_types recursively walks stmts collecting types of yielded exprs.
fn (mut t VTranspiler) collect_yield_types(stmts []Stmt, mut out []string) {
	for stmt in stmts {
		match stmt {
			ExprStmt {
				if stmt.value is Yield {
					y := stmt.value as Yield
					if val := y.value {
						ty := t.infer_expr_type(val)
						if ty.len > 0 {
							out << ty
						}
					}
				}
			}
			If {
				t.collect_yield_types(stmt.body, mut out)
				t.collect_yield_types(stmt.orelse, mut out)
			}
			For {
				t.collect_yield_types(stmt.body, mut out)
			}
			While {
				t.collect_yield_types(stmt.body, mut out)
			}
			FunctionDef {} // don't recurse into nested functions
			else {}
		}
	}
}

// get_op_type returns a string representation of the operator type for a given Operator enum value.
fn get_op_type(op Operator) string {
	return match op {
		Add { 'Add' }
		Sub { 'Sub' }
		Mult { 'Mult' }
		MatMult { 'MatMult' }
		Div { 'Div' }
		Mod { 'Mod' }
		Pow { 'Pow' }
		LShift { 'LShift' }
		RShift { 'RShift' }
		BitOr { 'BitOr' }
		BitXor { 'BitXor' }
		BitAnd { 'BitAnd' }
		FloorDiv { 'FloorDiv' }
	}
}

fn get_unary_op_type(op UnaryOperator) string {
	return match op {
		Invert { 'Invert' }
		Not { 'Not' }
		UAdd { 'UAdd' }
		USub { 'USub' }
	}
}

fn get_bool_op_type(op BoolOperator) string {
	return match op {
		And { 'And' }
		Or { 'Or' }
	}
}

fn get_cmp_op_type(op CmpOp) string {
	return match op {
		Eq { 'Eq' }
		NotEq { 'NotEq' }
		Lt { 'Lt' }
		LtE { 'LtE' }
		Gt { 'Gt' }
		GtE { 'GtE' }
		Is { 'Is' }
		IsNot { 'IsNot' }
		In { 'In' }
		NotIn { 'NotIn' }
	}
}

// map_python_format_spec converts a Python format spec (the part after ':')
// into a V interpolation format fragment (including the leading ':') when possible.
// This implements a minimal mapping for common cases: width, zero-pad, precision and type
// characters (f, F, e, E, g, G, d, i, x, X, o, s). If mapping is not possible,
// returns ':' + spec as a conservative fallback.
fn map_python_format_spec(spec string) string {
	if spec == '' {
		return ''
	}

	// Parse flags according to Python mini-language roughly:
	// [[fill]align][sign][#][0][width][,][.precision][type]
	mut s := spec
	mut align := u8(0)
	mut sign := u8(0)
	mut alt := false
	mut zero_pad := false
	mut grouping := false
	mut width := ''
	mut precision := ''
	mut typ := u8(0)

	// Fill and align: if s has at least 2 chars and second is one of <>=^
	if s.len >= 2 {
		a := s[1]
		if a == `<` || a == `>` || a == `^` || a == `=` {
			align = a
			s = s[2..]
		}
	}

	// Sign
	if s.len > 0 && (s[0] == `+` || s[0] == `-` || s[0] == ` `) {
		sign = s[0]
		s = s[1..]
	}

	// Alternate form '#'
	if s.len > 0 && s[0] == `#` {
		alt = true
		s = s[1..]
	}

	// Zero-pad flag
	if s.len > 0 && s[0] == `0` {
		zero_pad = true
		// strip single leading zero; width parsing will remove remaining digits
		s = s[1..]
	}

	// Grouping option (thousands separator)
	if s.contains(',') {
		grouping = true
	}

	// Type may be last char if letter
	if s.len > 0 {
		last := s[s.len - 1]
		if (last >= `a` && last <= `z`) || (last >= `A` && last <= `Z`) {
			typ = last
			s = s[0..s.len - 1]
		}
	}

	// Precision
	dot_idx := s.index('.') or { -1 }
	if dot_idx >= 0 {
		width = s[0..dot_idx]
		precision = s[dot_idx + 1..]
	} else {
		width = s
	}

	// Handle '=' alignment (sign-aware padding): enable zero_pad behavior
	if align == `=` {
		zero_pad = true
	}

	// If centre alignment for strings, map to a helper that centers the value
	if align == `^` {
		// Only implement center for string fields; otherwise fall back
		if typ == `s` {
			return 'CALL:fmt_center:' + width
		}
		return ':' + spec
	}

	// If grouping (',') for integer types, map to helper that inserts thousands separators.
	if grouping {
		if typ != 0 {
			t := typ.ascii_str()
			if t in ['d', 'i', 'x', 'X', 'o'] {
				// Return call marker with width and zero-pad flag
				zero_flag := if zero_pad { '1' } else { '0' }
				sign_char := if sign != 0 { sign.ascii_str() } else { '' }
				return 'CALL:fmt_group_int:' + width + ':' + zero_flag + ':' + t + ':' + sign_char
			}
			// Float-like grouping: return call to fmt_group_float with precision
			if t in ['f', 'F', 'e', 'E', 'g', 'G'] {
				zero_flag := if zero_pad { '1' } else { '0' }
				sign_char := if sign != 0 { sign.ascii_str() } else { '' }
				// include precision (may be empty)
				return 'CALL:fmt_group_float:' + width + ':' + zero_flag + ':' + t + ':' +
					precision + ':' + sign_char
			}
		}
		// For other grouping cases, fall back to raw spec
		return ':' + spec
	}

	// Build effective width string (left-align represented as negative width in earlier code)
	mut eff_width := width
	if align == `<` && eff_width != '' {
		eff_width = '-' + eff_width
	}

	// Build V-style fmt fragment
	mut vfmt := ''
	if typ != 0 {
		t := typ.ascii_str()
		// Float-like types
		if t in ['f', 'F', 'e', 'E', 'g', 'G'] {
			mut p := precision
			if p == '' {
				p = '6'
			}
			// Compose sign prefix if present
			mut sign_pref := ''
			if sign != 0 {
				sign_pref = sign.ascii_str()
			}
			if eff_width != '' {
				if zero_pad {
					vfmt = ':' + sign_pref + '0' + eff_width + '.' + p + t
				} else {
					vfmt = ':' + sign_pref + eff_width + '.' + p + t
				}
			} else {
				vfmt = ':' + sign_pref + '.' + p + t
			}
			return vfmt
		}
		// Integer-like
		if t in ['d', 'i', 'x', 'X', 'o'] {
			mut alt_pref := ''
			if alt {
				alt_pref = '#'
			}
			mut sign_pref := ''
			if sign != 0 {
				sign_pref = sign.ascii_str()
			}
			if eff_width != '' {
				if zero_pad {
					vfmt = ':' + sign_pref + '0' + eff_width + alt_pref + t
				} else {
					vfmt = ':' + sign_pref + eff_width + alt_pref + t
				}
			} else {
				vfmt = ':' + alt_pref + t
			}
			return vfmt
		}
		// String
		if t == 's' {
			if eff_width != '' {
				vfmt = ':' + eff_width
			} else {
				vfmt = ''
			}
			return vfmt
		}
		// Unknown type: fallback to raw spec
		return ':' + spec
	}

	// No explicit type
	if precision != '' {
		// assume float
		return ':.' + precision + 'f'
	}
	if eff_width != '' {
		if zero_pad {
			return ':0' + eff_width
		}
		return ':' + eff_width
	}
	return ':' + spec
}

fn get_expr_annotation(expr Expr) string {
	ann := match expr {
		Constant { expr.v_annotation }
		Name { expr.v_annotation }
		BinOp { expr.v_annotation }
		UnaryOp { expr.v_annotation }
		BoolOp { expr.v_annotation }
		Compare { expr.v_annotation }
		Call { expr.v_annotation }
		Attribute { expr.v_annotation }
		Subscript { expr.v_annotation }
		List { expr.v_annotation }
		Tuple { expr.v_annotation }
		Dict { expr.v_annotation }
		Set { expr.v_annotation }
		else { ?string(none) }
	}

	return ann or { '' }
}

// Infer the type of an expression for variable tracking
fn (mut t VTranspiler) infer_expr_type(expr Expr) string {
	if is_bool_expr(expr) {
		return 'bool'
	}
	match expr {
		Constant {
			c := expr
			// Check v_annotation first (e.g., Python float constants marked as "float")
			ann := c.v_annotation or { '' }
			if ann == 'float' {
				return 'f64'
			}
			if c.value is ComplexValue {
				return 'complex128'
			}
			if c.value is string {
				return 'string'
			}
			if c.value is int || c.value is i64 {
				return 'int'
			}
			if c.value is f64 {
				return 'f64'
			}
			return ''
		}
		Name {
			// Prefer any frontend-provided v_annotation on the Name node
			ann := get_expr_annotation(expr)
			if ann.len > 0 {
				if ann == 'float' {
					return 'f64'
				}
				if ann == 'int' {
					return 'int'
				}
				if ann == 'string' {
					return 'string'
				}
				if ann == 'bool' {
					return 'bool'
				}
				if ann == 'bytes' {
					return '[]u8'
				}
				// fallthrough for other annotations
			}
			// Propagate known type inferred during transpilation
			known := t.var_types[expr.id]
			if known != '' {
				return known
			}
			// Check if it's a function name - return its return type
			return t.func_return_types[expr.id]
		}
		BinOp {
			// If either operand is string, result is string (concatenation)
			left_type := t.infer_expr_type(expr.left)
			if left_type == 'string' {
				return 'string'
			}
			right_type := t.infer_expr_type(expr.right)
			if right_type == 'string' {
				return 'string'
			}
			// Numeric type promotion for typed parameters
			if left_type != '' && right_type != '' {
				left_rank := v_width_rank[left_type] or { -1 }
				right_rank := v_width_rank[right_type] or { -1 }
				if left_rank > 0 && right_rank > 0 {
					op_name := if expr.op is Sub { 'Sub' } else { 'Add' }
					return promote_numeric_type(left_type, right_type, op_name)
				}
			}
			// Simple numeric inference fallback
			if left_type == 'f64' || right_type == 'f64' {
				return 'f64'
			}
			if left_type == 'int' && right_type == 'int' {
				return 'int'
			}
			return ''
		}
		Call {
			// Prefer any frontend-provided annotation on the Call node
			ann := get_expr_annotation(expr)
			if ann.len > 0 {
				if ann == 'float' {
					return 'f64'
				}
				if ann == 'int' {
					return 'int'
				}
				if ann == 'string' {
					return 'string'
				}
				if ann == 'bool' {
					return 'bool'
				}
				if ann == 'bytes' {
					return '[]u8'
				}
				// fallthrough for other annotations
			}
			// Check known function return types
			if expr.func is Name {
				fn_name := (expr.func as Name).id
				// Check built-in function return types first
				match fn_name {
					'str' { return 'string' }
					'int' { return 'int' }
					'float' { return 'f64' }
					'bool' { return 'bool' }
					'len' { return 'int' }
					'input' { return 'string' }
					else { return t.func_return_types[fn_name] }
				}
			}
			// Method call: check .str() returns string, .len returns int, etc.
			if expr.func is Attribute {
				attr := (expr.func as Attribute).attr
				match attr {
					'str' {
						return 'string'
					}
					'len' {
						return 'int'
					}
					'keys' {
						return 'array'
					}
					'values' {
						return 'array'
					}
					else {
						// Check func_return_types for the method name
						rt := t.func_return_types[attr]
						if rt.len > 0 {
							return rt
						}
					}
				}
			}
			return ''
		}
		List {
			// Infer list type from elements
			lst := expr as List
			if lst.elts.len > 0 {
				elem_type := t.infer_expr_type(lst.elts[0])
				if elem_type.len > 0 {
					return '[]${elem_type}'
				}
			}
			return ''
		}
		Dict {
			// Infer dict type from keys/values
			d := expr as Dict
			if d.keys.len > 0 && d.values.len > 0 {
				mut key_type := ''
				mut val_type := ''
				for k_opt in d.keys {
					if k := k_opt {
						key_type = t.infer_expr_type(k)
						if key_type.len > 0 {
							break
						}
					}
				}
				for v in d.values {
					val_type = t.infer_expr_type(v)
					if val_type.len > 0 {
						break
					}
				}
				// Fall back to Any for unknown key/value types
				if key_type == '' {
					key_type = 'string'
				}
				if val_type == '' {
					val_type = 'Any'
				}
				return 'map[${key_type}]${val_type}'
			}
			return ''
		}
		Subscript {
			// Check v_annotation on the subscript
			ann := get_expr_annotation(expr)
			if ann != '' {
				return ann
			}
			// Infer element type from the collection's type
			sub := expr as Subscript
			coll_type := t.infer_expr_type(sub.value)
			if coll_type.starts_with('[]') {
				return coll_type[2..]
			}
			// Handle map subscript: map[K]V → V
			if coll_type.starts_with('map[') {
				bracket_end := coll_type.index(']') or { -1 }
				if bracket_end > 0 && bracket_end + 1 < coll_type.len {
					return coll_type[bracket_end + 1..]
				}
			}
			return ''
		}
		else {
			// Try v_annotation as last resort
			ann := get_expr_annotation(expr)
			if ann != '' {
				return ann
			}
			return ''
		}
	}
}

// Infer the element type of an iterable expression (for loop variable typing)
fn (mut t VTranspiler) infer_iter_elem_type(iter Expr) string {
	// For a List literal, check element types
	if iter is List {
		lst := iter as List
		if lst.elts.len > 0 {
			return t.infer_expr_type(lst.elts[0])
		}
	}
	// For a Name (variable), check var_types - strip [] prefix
	if iter is Name {
		vtype := t.var_types[(iter as Name).id]
		if vtype.starts_with('[]') {
			return vtype[2..]
		}
		if vtype == 'string' {
			return 'u8'
		}
	}
	// For range(), element type is int
	if iter is Call {
		c := iter as Call
		if c.func is Name {
			if (c.func as Name).id == 'range' {
				return 'int'
			}
		}
	}
	return ''
}

// Pre-scan body statements to find variables passed to mut-parameter functions
// so they can be declared with mut even before the call is processed
fn (mut t VTranspiler) prescan_mut_call_args(stmts []Stmt) {
	for stmt in stmts {
		t.prescan_mut_call_args_in_stmt(stmt)
	}
}

fn (mut t VTranspiler) prescan_mut_call_args_in_stmt(stmt Stmt) {
	match stmt {
		ExprStmt {
			t.prescan_mut_call_args_in_expr(stmt.value)
		}
		Assign {
			t.prescan_mut_call_args_in_expr(stmt.value)
		}
		Return {
			if val := stmt.value {
				t.prescan_mut_call_args_in_expr(val)
			}
		}
		If {
			t.prescan_mut_call_args_in_expr(stmt.test)
			t.prescan_mut_call_args(stmt.body)
			t.prescan_mut_call_args(stmt.orelse)
		}
		For {
			t.prescan_mut_call_args(stmt.body)
		}
		While {
			t.prescan_mut_call_args_in_expr(stmt.test)
			t.prescan_mut_call_args(stmt.body)
		}
		Assert {
			t.prescan_mut_call_args_in_expr(stmt.test)
		}
		else {}
	}
}

fn (mut t VTranspiler) prescan_mut_call_args_in_expr(expr Expr) {
	match expr {
		Call {
			// Check if this call has a known function with mut params
			mut fname := ''
			if expr.func is Name {
				fname = (expr.func as Name).id
			}
			if fname != '' {
				mut_indices := t.mut_param_indices[fname] or { []int{} }
				for i, arg in expr.args {
					if i in mut_indices {
						if arg is Name {
							t.extra_mut_vars[(arg as Name).id] = true
						}
					}
				}
			}
			// Recurse into args
			for arg in expr.args {
				t.prescan_mut_call_args_in_expr(arg)
			}
		}
		BinOp {
			t.prescan_mut_call_args_in_expr(expr.left)
			t.prescan_mut_call_args_in_expr(expr.right)
		}
		Compare {
			t.prescan_mut_call_args_in_expr(expr.left)
			for c in expr.comparators {
				t.prescan_mut_call_args_in_expr(c)
			}
		}
		UnaryOp {
			t.prescan_mut_call_args_in_expr(expr.operand)
		}
		NamedExpr {
			// NamedExpr (walrus operator) - treat as assignment
			t.prescan_mut_call_args_in_expr(expr.value)
		}
		else {}
	}
}

fn (mut t VTranspiler) visit_namedtuple_assign(_target_name string, _call Call) string {
	// Placeholder until full namedtuple lowering is restored.
	return ''
}

fn (mut t VTranspiler) infer_return_type(_stmts []Stmt) string {
	return 'Any'
}

// is_map_expr reports whether an expression is known to be a V map. Dict method
// names like `get`/`keys` are also valid user method names, so rewriting one to
// a map operation is only safe when the receiver really is a map.
pub fn (mut t VTranspiler) is_map_expr(expr Expr) bool {
	typ := t.infer_expr_type(expr)
	if typ.starts_with('map[') {
		return true
	}
	if typ.starts_with('[]') || typ.starts_with('[') || typ == 'string' {
		return false
	}
	if expr is Dict || expr is DictComp {
		return typ.starts_with('map[')
	}
	return false
}

// is_known_module_receiver reports whether a name refers to an imported module
// rather than a value, in which case `name.attr(...)` is a module-level call that
// the builtin table should translate instead of a method call.
pub fn (t VTranspiler) is_known_module_receiver(name string) bool {
	return t.imported_modules[name] or { false }
}

// seed_imported_classes records the field lists of classes visible through a
// `from ... import ...` in the scanned module, so that later struct literals and
// `isinstance`-style checks can resolve them without re-reading that module.
pub fn (mut t VTranspiler) seed_imported_classes(module_dotted string) {
	if t.registry.lookup(module_dotted).dotted == '' {
		return
	}
	for name in t.registry.symbols_named_in(module_dotted) {
		fields := t.registry.class_fields(module_dotted, name)
		if fields.len > 0 {
			if name !in t.imported_classes {
				t.imported_classes[name] = fields
			}
			t.known_classes[name] = fields
		}
		// Mirror mut-receiver methods so call sites can mark locals `mut`.
		for key, needs_mut in t.registry.mut_methods {
			if needs_mut && key.starts_with(name + '.') {
				cls := name
				meth := key[name.len + 1..]
				t.mut_receiver_methods['${cls}_${meth}'] = true
			}
		}
	}
}

// collect_mut_receivers finds local variables that are the receiver of a method
// call whose V method takes a `mut self`, returning (variable, method) pairs.
pub fn (t VTranspiler) collect_mut_receivers(stmts []Stmt) map[string]string {
	mut found := map[string]string{}
	t.scan_mut_receivers(stmts, mut found)
	return found
}

fn (t VTranspiler) scan_mut_receivers(stmts []Stmt, mut found map[string]string) {
	for stmt in stmts {
		t.scan_mut_receivers_stmt(stmt, mut found)
	}
}

fn (t VTranspiler) scan_mut_receivers_stmt(stmt Stmt, mut found map[string]string) {
	match stmt {
		ExprStmt {
			t.scan_mut_receivers_expr((stmt as ExprStmt).value, mut found)
		}
		Return {
			if v := (stmt as Return).value {
				t.scan_mut_receivers_expr(v, mut found)
			}
		}
		Assign {
			t.scan_mut_receivers_expr((stmt as Assign).value, mut found)
		}
		AnnAssign {
			if v := (stmt as AnnAssign).value {
				t.scan_mut_receivers_expr(v, mut found)
			}
		}
		If {
			for s in (stmt as If).body {
				t.scan_mut_receivers_stmt(s, mut found)
			}
			for s in (stmt as If).orelse {
				t.scan_mut_receivers_stmt(s, mut found)
			}
		}
		For {
			for s in (stmt as For).body {
				t.scan_mut_receivers_stmt(s, mut found)
			}
		}
		While {
			for s in (stmt as While).body {
				t.scan_mut_receivers_stmt(s, mut found)
			}
		}
		With {
			for s in (stmt as With).body {
				t.scan_mut_receivers_stmt(s, mut found)
			}
		}
		else {}
	}
}

fn (t VTranspiler) scan_mut_receivers_expr(expr Expr, mut found map[string]string) {
	match expr {
		Call {
			c := expr as Call
			if c.func is Attribute {
				attr := c.func as Attribute
				if attr.value is Name {
					recv := (attr.value as Name).id
					recv_type := t.var_types[recv] or { '' }
					if recv_type != '' && t.mut_receiver_methods['${recv_type}_${attr.attr}'] {
						found[recv] = attr.attr
					}
				}
				t.scan_mut_receivers_expr(attr.value, mut found)
			}
			for a in c.args {
				t.scan_mut_receivers_expr(a, mut found)
			}
		}
		else {}
	}
}

// constructor_name returns the class a call constructs, or '' when the callee is
// an ordinary function. Only a real class records a variable type here; treating
// `gap = max(...)` as a constructor would clobber the inferred type of `gap`.
fn (t VTranspiler) constructor_name(call Call) string {
	mut name := ''
	if call.func is Name {
		name = (call.func as Name).id
	} else if call.func is Attribute {
		name = (call.func as Attribute).attr
	}
	if name != '' && name in t.known_classes {
		return name
	}
	return ''
}

// v_return_type adapts a type expression to return-type position. A fixed-size
// array annotation such as `tuple[int, int]` maps to `[2]int` in variable
// position, but V requires multiple return values to be written `(int, int)`.
fn v_return_type(typ string) string {
	if typ.len < 3 || typ[0] != `[` {
		return typ
	}
	close_idx := typ.index_u8(`]`)
	if close_idx < 2 {
		return typ
	}
	count := typ[1..close_idx].int()
	elem := typ[close_idx + 1..]
	if count <= 0 {
		return typ
	}
	mut parts := []string{}
	for _ in 0 .. count {
		parts << elem
	}
	return '(${parts.join(', ')})'
}
