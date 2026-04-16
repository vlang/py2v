module main

const max_generated_line_len = 121

pub struct VTranspiler {
mut:
	usings  []string
	tmp_gen TmpVarGen
	// Maps and state tracked during transpilation
	var_types                   map[string]string
	escaped_identifiers         map[string]bool
	current_class_name          string
	global_vars                 map[string]bool
	extra_mut_vars              map[string]bool
	mut_param_indices           map[string][]int
	func_defaults               map[string][]string
	func_param_count            map[string]int
	func_return_types           map[string]string
	generated_code_has_any_type bool
	// Class metadata
	class_attr_symbols  map[string]map[string]string
	class_direct_fields map[string][]string
	class_base_names    map[string][]string
	known_classes       map[string][]string
	// Module name for emitted code
	module_name string
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
		usings:                      []string{}
		tmp_gen:                     new_tmp_var_gen()
		var_types:                   map[string]string{}
		escaped_identifiers:         map[string]bool{}
		current_class_name:          ''
		global_vars:                 map[string]bool{}
		extra_mut_vars:              map[string]bool{}
		mut_param_indices:           map[string][]int{}
		func_defaults:               map[string][]string{}
		func_param_count:            map[string]int{}
		func_return_types:           map[string]string{}
		generated_code_has_any_type: false
		class_attr_symbols:          map[string]map[string]string{}
		class_direct_fields:         map[string][]string{}
		class_base_names:            map[string][]string{}
		known_classes:               map[string][]string{}
		module_name:                 ''
	}
}

// visit_module emits the top-level V module source for a Module node.
pub fn (mut t VTranspiler) visit_module(node Module) string {
	mut module_name := t.module_name
	if module_name.len == 0 {
		module_name = 'main'
	}

	mut decl_parts := []string{}
	mut main_parts := []string{}

	mut first_stmt := true
	for stmt in node.body {
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
			FunctionDef, AsyncFunctionDef, ClassDef {
				decl_parts << s
			}
			else {
				// Type alias declarations (e.g. `type Foo = A | B`) must live at
				// module scope, not inside fn main().
				if s.starts_with('type ') {
					decl_parts << s
				} else {
					main_parts << s
				}
			}
		}
	}

	mut parts := []string{}
	parts << '@[translated]'
	parts << 'module ${module_name}'

	if t.usings.len > 0 {
		mut import_lines := []string{}
		for u in t.usings {
			import_lines << 'import ${u}'
		}
		parts << import_lines.join('\n')
	}

	if decl_parts.len > 0 {
		parts << decl_parts.join('\n\n')
	}

	if t.generated_code_has_any_type {
		parts << 'type Any = bool | int | i64 | f64 | string | []u8'
	}

	if main_parts.len > 0 {
		// If decl_parts already contains a `fn main()` (from the __name__
		// guard rewrite), inject the module-level init stmts at the start of
		// that function's body instead of emitting a second fn main().
		mut merged := false
		for i, dp in decl_parts {
			if dp.starts_with('fn main()') {
				mut indented := []string{}
				for p in main_parts {
					indented << indent(p, 1, '\t')
				}
				// Insert init lines after the opening `fn main() {` line
				open_brace := dp.index('{') or { -1 }
				if open_brace >= 0 {
					head := dp[0..open_brace + 1]
					tail := dp[open_brace + 1..]
					injected := indented.join('\n')
					decl_parts[i] = '${head}\n${injected}${tail}'
					// Rebuild the decl_parts section in parts
					// (it was already appended above; replace the last block)
					parts[parts.len - 1] = decl_parts.join('\n\n')
					merged = true
					break
				}
			}
		}
		if !merged {
			mut main_body := ''
			mut indented := []string{}
			for p in main_parts {
				indented << indent(p, 1, '\t')
			}
			main_body = indented.join('\n')
			parts << 'fn main() {\n${main_body}\n}'
		}
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
		FunctionDef { return t.visit_function_def(stmt) }
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

// visit_function_def emits V code for a Python FunctionDef node.
pub fn (mut t VTranspiler) visit_function_def(node FunctionDef) string {
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
	signature << 'fn'

	// Handle class method receiver
	if node.is_class_method {
		emitted_receiver := emitted_class_name(node.class_name)
		if 'self' in node.mutable_vars || node.name == '__init__' {
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

		mut typename := ''
		if ann := arg.annotation {
			typename = t.typename_from_annotation(ann)
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

	// Handle vararg
	if vararg := node.args.vararg {
		mut typename := ''
		if ann := vararg.annotation {
			typename = t.typename_from_annotation(ann)
		}
		if typename.starts_with('[]') {
			typename = '...' + typename[2..]
		} else if typename == '' {
			typename = '...Any'
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

	signature << '${node.name}(${args_strs.join(', ')})'

	// Pre-scan body to populate var_types for return type inference
	t.prescan_body_types(node.body)

	// Return type
	if !node.is_void && !node.is_generator && node.name != '__init__' {
		if ret := node.returns {
			ret_type := t.typename_from_annotation(ret)
			signature << ret_type
			t.func_return_types[node.name] = ret_type
		} else {
			// Infer return type from return statements
			mut inferred := t.infer_return_type(node.body)
			// Fall back to Any when function returns a value but type can't be inferred
			if inferred.len == 0 {
				inferred = 'Any'
				t.generated_code_has_any_type = true
			}
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
				nested_fndefs << t.visit_function_def(stmt)
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

	func_code := '${signature.join(' ')} {\n${body}\n}'

	// Restore var_types and escaped_identifiers from parent scope
	t.var_types = saved_var_types.clone()
	t.escaped_identifiers = saved_escaped_identifiers.clone()

	if nested_fndefs.len > 0 {
		t.current_class_name = saved_current_class
		return nested_fndefs.join('\n') + '\n' + func_code
	}
	t.current_class_name = saved_current_class
	return func_code
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
	}
	return t.visit_function_def(fd)
}

// visit_class_def emits V code for a ClassDef node.
pub fn (mut t VTranspiler) visit_class_def(node ClassDef) string {
	emitted_name := emitted_class_name(node.name)
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

	if node.declarations.len > 0 {
		mut has_typed_fields := false
		for decl, typename in node.declarations {
			if decl in class_attr_syms && decl !in init_field_names {
				continue
			}
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
				fields << t.indent_code('${decl} ${typ} = ${default_str}', 1)
			} else {
				fields << t.indent_code('${decl} ${typ}', 1)
			}
			field_names << decl
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
		'pub struct ${emitted_name} {\n${all_parts.join('\n')}\n}'
	} else {
		'pub struct ${emitted_name} {\n}'
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

	// Process body (methods)
	mut methods := []string{}
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
				methods << t.visit_function_def(fd)
			}
			else {}
		}
	}

	if methods.len > 0 {
		return struct_def + '\n\n' + methods.join('\n\n')
	}
	return struct_def
}

// visit_assign emits V code for an Assign statement.
pub fn (mut t VTranspiler) visit_assign(node Assign) string {
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
							// All unpack targets get mut (V needs this for array element operations)
							subkw := if !any_redefined { 'mut ' } else { '' }
							assigns << '${subkw}${t.visit_expr(st)} ${op} ${tmp_var}[${i}]'
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

		// All starred unpack targets need mut for V array operations
		assigns << 'mut ${t.visit_expr(target_elt)} := ${idx_val}'
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
	op := op_to_symbol(op_type)
	return '${target} ${op}= ${val}'
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
			return '${kw}${target} ${op} ${type_str}{}'
		}

		return '${kw}${target} ${op} ${val_str}'
	}

	return '${kw}${target} ${op} ${type_str}{}'
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
	if node.iter is Call {
		call := node.iter as Call
		if call.func is Name {
			fname := (call.func as Name).id
			if fname == 'range' && call.args.len == 3 {
				start := t.visit_expr(call.args[0])
				end := t.visit_expr(call.args[1])
				step := t.visit_expr(call.args[2])
				buf << 'for ${target} := ${start}; ${target} < ${end}; ${target} += ${step} {'
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

	// Infer loop variable type from iterable
	if node.target is Name {
		iter_type := t.infer_iter_elem_type(node.iter)
		if iter_type != '' {
			t.var_types[(node.target as Name).id] = iter_type
		}
	}

	iter := t.visit_expr(node.iter)
	buf << 'for ${target} in ${iter} {'
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
		if exc is Call {
			call := exc as Call
			fname := t.visit_expr(call.func)
			msg := if call.args.len > 0 { t.visit_expr(call.args[0]) } else { "''" }
			return "panic('${fname}: ' + ${msg})"
		}
		name := t.visit_expr(exc)
		return "panic('${name}')"
	}

	return "panic('Exception')"
}

// visit_try emits V code for a Try statement.
// V uses Result types and `or {}` blocks instead of exceptions; we emit the
// try body as-is and each except handler inside an `// except` comment header
// followed by the handler body as real (but guarded) V code so it stays visible
// and compilable after manual adaptation.
pub fn (mut t VTranspiler) visit_try(node Try) string {
	mut buf := []string{}
	has_handlers := node.handlers.len > 0

	// Convert finally blocks to V's defer for guaranteed cleanup
	if node.finalbody.len > 0 {
		buf << 'defer {'
		for stmt in node.finalbody {
			result := t.visit_stmt(stmt)
			for line in result.split('\n') {
				if line.len > 0 {
					buf << '\t${line}'
				}
			}
		}
		buf << '}'
	}

	// Emit try body directly — wrap fallible calls with `or {}` manually
	if has_handlers {
		buf << '// try: (V: wrap fallible calls below with `or {}`)'
	}
	for stmt in node.body {
		buf << t.visit_stmt(stmt)
	}

	// Emit each except handler with real body code inside a dead-code block
	// so the logic is visible and easy to adapt.
	for handler in node.handlers {
		mut header := '// except'
		if typ := handler.typ {
			typ_name := t.visit_expr(typ)
			if name := handler.name {
				header = '// except ${typ_name} as ${name}:'
				// Temporarily bind the exception var as string so uses compile
				t.var_types[name] = 'string'
			} else {
				header = '// except ${typ_name}:'
			}
		} else {
			header = '// except:'
		}
		buf << header
		buf << '// NOTE: V uses Result types; adapt body to use `or { ... }` blocks'
		// Emit handler body as real code (it may reference `e` which won't exist
		// at runtime, but keeps the logic visible and syntactically valid)
		for stmt in handler.body {
			buf << t.visit_stmt(stmt)
		}
		// Clean up temporary binding
		if name := handler.name {
			t.var_types.delete(name)
		}
	}

	return buf.join('\n')
}

// visit_assert emits V code for an Assert statement.
pub fn (mut t VTranspiler) visit_assert(node Assert) string {
	test := t.visit_expr(node.test)
	return 'assert ${test}'
}

// visit_import handles Python import statements (suppressed for V).
pub fn (mut t VTranspiler) visit_import(node Import) string {
	// Suppress imports - they're handled differently in V
	return ''
}

// visit_import_from handles Python 'from X import Y' (suppressed for V).
pub fn (mut t VTranspiler) visit_import_from(node ImportFrom) string {
	// Suppress imports
	return ''
}

// visit_global emits a comment for Python global declarations (V lacks global).
pub fn (mut t VTranspiler) visit_global(node Global) string {
	names := node.names.join(', ')
	return "// global ${names}  // V doesn't support global keyword"
}

// visit_nonlocal emits a comment for Python nonlocal declarations (V lacks nonlocal).
pub fn (mut t VTranspiler) visit_nonlocal(node Nonlocal) string {
	names := node.names.join(', ')
	return "// nonlocal ${names}  // V doesn't support nonlocal keyword"
}

// visit_expr_stmt emits V code for an expression statement (ExprStmt).
pub fn (mut t VTranspiler) visit_expr_stmt(node ExprStmt) string {
	// Check for ellipsis
	if node.value is Constant {
		c := node.value as Constant
		if c.value is EllipsisValue {
			return '// ...'
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
			return "'${escape_string(node.value as string)}'"
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
	return escape_keyword(node.id)
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
		// Negative exponent: Python auto-promotes to float (2**-1 = 0.5)
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
	if lann == 'bool' || rann == 'bool' {
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
					if vargs.len > 0 {
						return 'self.${base_name}.${method}(${vargs.join(', ')})'
					}
					return 'self.${base_name}.${method}()'
				}
				return ''
			}
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
				return '${obj}.bytes().all(fn (c u8) bool { return c.is_digit() })'
			}
			'isalpha' {
				return '${obj}.bytes().all(fn (c u8) bool { return c.is_letter() })'
			}
			'isalnum' {
				return '${obj}.bytes().all(fn (c u8) bool { return c.is_alnum() })'
			}
			'isspace' {
				return '${obj}.bytes().all(fn (c u8) bool { return c.is_space() })'
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
				if vargs.len > 0 {
					return '${obj}.index(${vargs[0]}) or { -1 }'
				}
				return '-1'
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
			// Dict methods
			'keys' {
				return '${obj}.keys()'
			}
			'values' {
				return '${obj}.values()'
			}
			'items' {
				// V doesn't have items(), iterate directly
				return '${obj} // .items() - iterate with for k, v in dict'
			}
			'get' {
				if vargs.len >= 2 {
					return '${obj}[${vargs[0]}] or { ${vargs[1]} }'
				}
				if vargs.len == 1 {
					return '${obj}[${vargs[0]}] or { none }'
				}
				return obj
			}
			'update' {
				if vargs.len > 0 {
					return '// ${obj}.update() - manually merge dicts'
				}
				return obj
			}
			else {}
		}
	}

	// Check if this is a struct constructor call (known dataclass)
	if fname in t.known_classes {
		emitted_ctor := emitted_class_name(fname)
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
	attr := node.attr
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
		return '{}'
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
	map_type := 'map[${k}]${v}'

	buf << '(fn () ${map_type} {'
	buf << 'mut result := ${map_type}{}'

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
					// For stepped range, use a different approach
					start := t.visit_expr(call.args[0])
					end := t.visit_expr(call.args[1])
					step := t.visit_expr(call.args[2])
					result = '[]int{len: (${end} - ${start}) / ${step}, init: ${start} + index * ${step}}'
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

// visit_formatted_value emits V code for formatted value parts (FormattedValue).
pub fn (mut t VTranspiler) visit_formatted_value(node FormattedValue) string {
	expr := t.visit_expr(node.value)
	// Do not append .str() — V string interpolation / concatenation uses values directly
	return '(${expr})'
}

// visit_joined_str emits V code for joined string (f-string / JoinedStr).
pub fn (mut t VTranspiler) visit_joined_str(node JoinedStr) string {
	mut parts := []string{}
	for val in node.values {
		if val is Constant {
			c := val as Constant
			if c.value is string {
				s := c.value as string
				parts << "'${escape_string(s)}'"
				continue
			}
		}
		parts << t.visit_expr(val)
	}
	if parts.len == 0 {
		return "''"
	}
	if parts.len == 1 {
		return parts[0]
	}
	flat := parts.join(' + ')
	if flat.len <= max_generated_line_len {
		return flat
	}
	mut lines := []string{}
	lines << '('
	lines << '\t${parts[0]}'
	for p in parts[1..] {
		lines << '\t+ ${p}'
	}
	lines << ')'
	return lines.join('\n')
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
			index := t.typename_from_annotation(a.slice)

			mapped := v_container_type_map[value] or { value }
			if value == 'Tuple' || value == 'tuple' {
				return '(${index})'
			}
			if value == 'Dict' || value == 'dict' {
				// Handle Dict[K, V]
				return 'map[${index}]'
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
				// General union: just use left type
				return map_type(left)
			}
			return default_type
		}
		Constant {
			if a.value is string {
				return a.value as string
			}
			if a.value is NoneValue {
				return 'None'
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
		else {}
	}
}

// Infer the return type of a function from its return statements
fn (mut t VTranspiler) infer_return_type(stmts []Stmt) string {
	mut ret_type := ''
	for stmt in stmts {
		match stmt {
			Return {
				if val := stmt.value {
					mut inferred := t.infer_expr_type(val)
					// Fallback: check v_annotation from the frontend
					if inferred == '' {
						inferred = get_expr_annotation(val)
					}
					if inferred != '' && inferred != 'none' {
						// Map Python type names to V types
						inferred = match inferred {
							'float' { 'f64' }
							'str' { 'string' }
							else { inferred }
						}
						if ret_type == '' {
							ret_type = inferred
						}
						// If we get conflicting types, keep the first non-empty one
					}
				}
			}
			If {
				sub := t.infer_return_type(stmt.body)
				if sub != '' && ret_type == '' {
					ret_type = sub
				}
				sub2 := t.infer_return_type(stmt.orelse)
				if sub2 != '' && ret_type == '' {
					ret_type = sub2
				}
			}
			For {
				sub := t.infer_return_type(stmt.body)
				if sub != '' && ret_type == '' {
					ret_type = sub
				}
			}
			While {
				sub := t.infer_return_type(stmt.body)
				if sub != '' && ret_type == '' {
					ret_type = sub
				}
			}
			Try {
				sub := t.infer_return_type(stmt.body)
				if sub != '' && ret_type == '' {
					ret_type = sub
				}
			}
			else {}
		}
	}
	return ret_type
}

// Pre-scan function body to populate var_types for return type inference
fn (mut t VTranspiler) prescan_body_types(stmts []Stmt) {
	for stmt in stmts {
		match stmt {
			Assign {
				// Track variable types from assignments
				for target in stmt.targets {
					if target is Name {
						n := target as Name
						inferred := t.infer_expr_type(stmt.value)
						if inferred != '' {
							t.var_types[n.id] = inferred
						}
					}
				}
			}
			AnnAssign {
				// Track annotated variables
				if stmt.target is Name {
					n := stmt.target as Name
					type_str := t.typename_from_annotation(stmt.annotation)
					if type_str != '' {
						t.var_types[n.id] = type_str
					}
				}
			}
			AugAssign {
				// Track augmented assignment types (e.g., total += n preserves type)
				if stmt.target is Name {
					n := stmt.target as Name
					existing := t.var_types[n.id]
					if existing == '' {
						inferred := t.infer_expr_type(stmt.value)
						if inferred != '' {
							t.var_types[n.id] = inferred
						}
					}
				}
			}
			FunctionDef {
				// Track nested function definitions for their return types
				if !stmt.is_void {
					if ret := stmt.returns {
						ret_type := t.typename_from_annotation(ret)
						if ret_type != '' {
							t.func_return_types[stmt.name] = ret_type
						}
					}
				}
			}
			else {}
		}
	}
}
