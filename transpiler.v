module main

const max_generated_line_len = 121

// VTranspiler - transpiles Python AST to V code
pub struct VTranspiler {
mut:
	usings                      []string
	indent_str                  string = '\t'
	module_name                 string = 'main'
	tmp_var_id                  int
	generated_code_has_any_type bool
	known_classes               map[string][]string // class name -> field names in order
	class_direct_fields         map[string][]string // class name -> direct (non-inherited) fields
	class_base_names            map[string][]string // class name -> direct base class names
	current_class_name          string
	mut_param_indices           map[string][]int    // function name -> indices of mut parameters
	func_defaults               map[string][]string // function name -> default values for trailing params
	func_param_count            map[string]int      // function name -> total parameter count
	var_types                   map[string]string   // variable name -> inferred type ("bool", "string", etc.)
	func_return_types           map[string]string   // function name -> return type ("string", "int", etc.)
	extra_mut_vars              map[string]bool     // variables that need mut because passed to mut params
	global_vars                 map[string]bool     // module-level variables (declared in __global)
	escaped_identifiers         map[string]bool     // identifiers escaped due to V built-in type name conflict
}

// Create a new VTranspiler
pub fn new_transpiler() VTranspiler {
	return VTranspiler{
		usings: []string{}
	}
}

// Add a using/import
pub fn (mut t VTranspiler) add_using(mod string) {
	if mod !in t.usings {
		t.usings << mod
	}
}

// Generate a new temporary variable name
pub fn (mut t VTranspiler) new_tmp(prefix string) string {
	t.tmp_var_id++
	return '__${prefix}${t.tmp_var_id}'
}

// Indent code
pub fn (t VTranspiler) indent_code(code string, level int) string {
	return indent(code, level, t.indent_str)
}

// Generate the module header with imports
pub fn (t VTranspiler) usings_code() string {
	mut buf := []string{}
	buf << '@[translated]'
	buf << 'module ${t.module_name}'

	if t.usings.len > 0 {
		buf << ''
		mut sorted_usings := t.usings.clone()
		sorted_usings.sort()
		for mod in sorted_usings {
			buf << 'import ${mod}'
		}
	}

	if t.generated_code_has_any_type {
		buf << ''
		buf << 'type Any = bool | int | i64 | f64 | string | []byte'
	}

	return buf.join('\n')
}

// Main entry point - transpile a module
pub fn (mut t VTranspiler) visit_module(mod Module) string {
	// Separate module-level assignments from definitions
	// V requires __global block for module-level variables, and definitions before code
	mut global_assigns := []string{}
	mut defined_vars := map[string]bool{} // Track already defined variables
	mut definitions := []string{}
	mut other_stmts := []string{}
	mut imported_exceptions := []string{}
	mut exported_names := []string{}

	// Pre-pass: identify module-level variable names and infer types (will become __global)
	for stmt in mod.body {
		match stmt {
			Assign {
				for target in stmt.targets {
					if target is Name {
						n := target as Name
						t.global_vars[n.id] = true
						// Infer type from value for use in function bodies
						inferred := t.infer_expr_type(stmt.value)
						if inferred.len > 0 {
							t.var_types[n.id] = inferred
						}
					}
				}
			}
			AnnAssign {
				if stmt.target is Name {
					n := stmt.target as Name
					t.global_vars[n.id] = true
					// Infer type from annotation
					ann_type := t.typename_from_annotation(stmt.annotation)
					if ann_type.len > 0 {
						t.var_types[n.id] = ann_type
					}
				}
			}
			else {}
		}
	}

	// First pass: process function/class definitions to register signatures
	for stmt in mod.body {
		match stmt {
			ImportFrom {
				mod_name := stmt.mod or { '' }
				// Package __init__.py pattern: from ...exceptions import FooException, ...
				if mod_name.ends_with('.exceptions') || mod_name == 'exceptions' {
					for alias in stmt.names {
						if alias.name.ends_with('Exception') || alias.name == 'WebDriverException' {
							if alias.name !in imported_exceptions {
								imported_exceptions << alias.name
							}
						}
					}
				}
			}
			Assign {
				// Track __all__ for exported-name filtering/order.
				if stmt.targets.len == 1 && stmt.targets[0] is Name {
					n := stmt.targets[0] as Name
					if n.id == '__all__' {
						exported_names = extract_string_list(stmt.value)
					}
				}
			}
			FunctionDef, AsyncFunctionDef, ClassDef {
				result := t.visit_stmt(stmt)
				if result.len > 0 {
					definitions << result
				}
			}
			else {}
		}
	}

	// Pre-scan remaining statements for variables passed to mut params
	t.prescan_mut_call_args(mod.body)

	// Second pass: process non-definition statements
	for stmt in mod.body {
		match stmt {
			FunctionDef, AsyncFunctionDef, ClassDef {
				// Already processed above
			}
			Assign {
				// Check if this is a first-time definition or reassignment
				// Extract variable names from targets
				mut is_first_def := true
				for target in stmt.targets {
					if target is Name {
						n := target as Name
						if n.id in defined_vars {
							is_first_def = false
							break
						}
					}
				}

				result := t.visit_assign(stmt)
				if result.len > 0 {
					if is_first_def {
						// First definition goes in __global
						// Mark variables as defined and as global
						for target in stmt.targets {
							if target is Name {
								n := target as Name
								defined_vars[n.id] = true
								t.global_vars[n.id] = true
							}
						}
						// Convert := to = and strip mut for __global block
						mut ga := result.replace(' := ', ' = ')
						if ga.starts_with('mut ') {
							ga = ga[4..]
						}
						global_assigns << ga
					} else {
						// Reassignment goes in other statements
						other_stmts << result
					}
				}
			}
			AnnAssign {
				// Check if already defined
				mut var_name := ''
				if stmt.target is Name {
					n := stmt.target as Name
					var_name = n.id
				}

				result := t.visit_stmt(stmt)
				if result.len > 0 {
					if var_name !in defined_vars {
						defined_vars[var_name] = true
						if var_name.len > 0 {
							t.global_vars[var_name] = true
						}
						mut ga := result.replace(' := ', ' = ')
						if ga.starts_with('mut ') {
							ga = ga[4..]
						}
						global_assigns << ga
					} else {
						other_stmts << result
					}
				}
			}
			ExprStmt {
				// Skip module-level docstrings (bare string constants)
				if stmt.value is Constant {
					c := stmt.value as Constant
					if c.value is string {
						continue
					}
				}
				result := t.visit_stmt(stmt)
				if result.len > 0 {
					other_stmts << result
				}
			}
			else {
				result := t.visit_stmt(stmt)
				if result.len > 0 {
					other_stmts << result
				}
			}
		}
	}

	// Build code with proper ordering
	mut code_parts := []string{}

	// Add global block if there are module-level assignments
	if global_assigns.len > 0 {
		code_parts << '__global ('
		for ga in global_assigns {
			code_parts << '\t${ga}'
		}
		code_parts << ')'
	}

	// Add definitions (functions, classes)
	for i, def in definitions {
		if i > 0 {
			code_parts << ''
		}
		code_parts << def
	}

	// Add exception union alias for package-style exports (e.g., selenium/common/__init__.py)
	mut union_names := []string{}
	if exported_names.len > 0 && imported_exceptions.len > 0 {
		for name in exported_names {
			if name in imported_exceptions {
				union_names << name
			}
		}
	} else if imported_exceptions.len > 1 {
		union_names = imported_exceptions.clone()
	}
	if union_names.len > 1 {
		if code_parts.len > 0 {
			code_parts << ''
		}
		code_parts << format_union_type_alias('WebDriverExceptions', union_names, max_generated_line_len)
	}

	// Add other statements - must be wrapped in fn main() if present
	if other_stmts.len > 0 {
		code_parts << ''
		code_parts << 'fn main() {'
		for stmt in other_stmts {
			code_parts << '\t${stmt}'
		}
		code_parts << '}'
	}

	mut code := code_parts.join('\n')

	// Add module docstring comment if present
	if doc := mod.docstring_comment {
		// Convert multi-line docstrings to single-line comment with first line
		first_line := doc.split('\n')[0].trim_space()
		if first_line.len > 0 {
			code = '// ${first_line}\n\n' + code
		}
	}

	// Check if code contains "Any" type
	t.generated_code_has_any_type = code.contains(' Any') || code.contains('[Any]')
		|| code.contains('Any{')

	header := t.usings_code()
	if header.len > 0 {
		return header + '\n\n' + code + '\n'
	}
	return code + '\n'
}

fn extract_string_list(expr Expr) []string {
	mut out := []string{}
	match expr {
		List {
			for e in expr.elts {
				if e is Constant {
					c := e as Constant
					if c.value is string {
						out << (c.value as string)
					}
				}
			}
		}
		Tuple {
			for e in expr.elts {
				if e is Constant {
					c := e as Constant
					if c.value is string {
						out << (c.value as string)
					}
				}
			}
		}
		else {}
	}
	return out
}

fn format_union_type_alias(name string, variants []string, max_col int) string {
	if variants.len == 0 {
		return 'type ${name} = Any'
	}
	mut lines := []string{}
	mut line := 'type ${name} = ${variants[0]}'
	for i := 1; i < variants.len; i++ {
		candidate := '${line} | ${variants[i]}'
		if candidate.len <= max_col {
			line = candidate
		} else {
			lines << line
			line = '\t| ${variants[i]}'
		}
	}
	lines << line
	return lines.join('\n')
}

// Visit a list of statements
pub fn (mut t VTranspiler) visit_body(stmts []Stmt) string {
	mut parts := []string{}
	mut prev_was_func_or_class := false
	for stmt in stmts {
		result := t.visit_stmt(stmt)
		if result.len > 0 {
			// Add blank line between function/class definitions
			is_func_or_class := stmt is FunctionDef || stmt is AsyncFunctionDef || stmt is ClassDef
			if prev_was_func_or_class && is_func_or_class {
				parts << ''
			}
			parts << result
			prev_was_func_or_class = is_func_or_class
		}
	}
	return parts.join('\n')
}

// Visit statements in a body and apply indentation
fn (mut t VTranspiler) visit_body_stmts(stmts []Stmt, indent_level int) []string {
	mut lines := []string{}
	mut prev_was_if_no_else := false
	for stmt in stmts {
		result := t.visit_stmt(stmt)
		if result.len > 0 {
			// Add blank line after if-without-else
			if prev_was_if_no_else {
				lines << ''
			}
			lines << t.indent_code(result, indent_level)
			// Track if this was an if without else, or a with block
			if stmt is If {
				if_stmt := stmt as If
				prev_was_if_no_else = if_stmt.orelse.len == 0
			} else if stmt is With || stmt is AsyncWith {
				prev_was_if_no_else = true
			} else {
				prev_was_if_no_else = false
			}
		}
	}
	return lines
}

// Visit a statement
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

// Visit an expression
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

// Visit FunctionDef
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
		if 'self' in node.mutable_vars || node.name == '__init__' {
			signature << '(mut self ${node.class_name})'
		} else {
			signature << '(self ${node.class_name})'
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
		yield_type := t.infer_generator_yield_type(node)
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

// Visit AsyncFunctionDef (converted to sync)
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

// Visit ClassDef
pub fn (mut t VTranspiler) visit_class_def(node ClassDef) string {
	mut fields := []string{}
	mut field_names := []string{}
	mut base_names := []string{}

	if node.declarations.len > 0 {
		mut has_typed_fields := false
		for decl, typename in node.declarations {
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
			fields << t.indent_code('${decl} ${typ}', 1)
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
			embeds << t.indent_code(base_name, 1)
		}
	}

	mut all_parts := []string{}
	all_parts << embeds
	all_parts << fields

	mut struct_def := if all_parts.len > 0 {
		'pub struct ${node.name} {\n${all_parts.join('\n')}\n}'
	} else {
		'pub struct ${node.name} {\n}'
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

// Visit Return
pub fn (mut t VTranspiler) visit_return(node Return) string {
	if val := node.value {
		expr := t.visit_expr(val)
		// Strip outer parentheses from return expression
		stripped := strip_outer_parens(expr)
		return 'return ${stripped}'
	}
	return 'return'
}

// Visit Delete
pub fn (mut t VTranspiler) visit_delete(node Delete) string {
	mut parts := []string{}
	for target in node.targets {
		if target is Subscript {
			// Deleting a subscript - list[i] or dict[key]
			sub := target as Subscript
			obj := t.visit_expr(sub.value)
			idx := t.visit_expr(sub.slice)
			// For lists, use .delete(index)
			// For dicts, use .delete(key)
			parts << '${obj}.delete(${idx})'
		} else if target is Name {
			// Can't delete a variable in V - comment it out
			parts << '// del ${t.visit_expr(target)} - V does not support deleting variables'
		} else {
			// Fallback
			parts << '// del ${t.visit_expr(target)}'
		}
	}
	return parts.join('\n')
}

// Visit Assign
pub fn (mut t VTranspiler) visit_assign(node Assign) string {
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
					assigns << t.handle_starred_unpack(elts, value_str, node)
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
								// If is_mutable is set, it means the name was used mutably somewhere
								// For a swap, both vars should be mutable
								if !st.is_mutable {
									all_names_mutable = false
								}
							} else if st is Subscript || st is Attribute {
								// Subscript/Attribute targets always need =
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
								// Only add mut for new definitions
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
					assigns << t.handle_starred_unpack(elts, value_str, node)
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

	return assigns.join('\n')
}

// Handle starred unpacking in assignments
fn (mut t VTranspiler) handle_starred_unpack(elts []Expr, value_str string, node Assign) string {
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

// Visit AugAssign
pub fn (mut t VTranspiler) visit_aug_assign(node AugAssign) string {
	target := t.visit_expr(node.target)
	op := op_to_symbol(get_op_type(node.op))
	val := t.visit_expr(node.value)
	return '${target} ${op}= ${val}'
}

// Visit AnnAssign
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
				return '${kw}${target} := [${elts.join(', ')}]'
			}
			return '${kw}${target} := ${type_str}{}'
		}

		return '${kw}${target} := ${val_str}'
	}

	return '${kw}${target} := ${type_str}{}'
}

// Visit For
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

// Visit AsyncFor (converted to sync)
pub fn (mut t VTranspiler) visit_async_for(node AsyncFor) string {
	mut buf := []string{}
	buf << '// WARNING: async for converted to sync for'

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

// Visit While
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

// Visit If
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

// Visit With - use 'if true {}' blocks for scoping
pub fn (mut t VTranspiler) visit_with(node With) string {
	mut buf := []string{}

	buf << 'if true {'
	for item in node.items {
		context := t.visit_expr(item.context_expr)
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
					}
				}
			}
			// Check if context is os.create or os.open
			if context.starts_with('os.create(') || context.starts_with('os.open(') {
				kw = 'mut '
			}
			buf << '\t${kw}${target} := ${context}'
		} else {
			buf << '\t${context}'
		}
	}

	buf << t.visit_body_stmts(node.body, 1)

	buf << '}'

	return buf.join('\n')
}

// Visit AsyncWith (converted to sync)
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

// Visit Raise
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

// Visit Try
pub fn (mut t VTranspiler) visit_try(node Try) string {
	mut buf := []string{}

	// V doesn't have try/except - convert to comments and execute body directly
	// In the future, this could use V's or{} blocks for error handling
	buf << '// try {'
	for stmt in node.body {
		buf << t.visit_stmt(stmt)
	}
	buf << '// } catch {'

	if node.handlers.len > 0 {
		for handler in node.handlers {
			if typ := handler.typ {
				typ_name := t.visit_expr(typ)
				buf << '// except ${typ_name}:'
			} else {
				buf << '// except:'
			}
			buf << '// NOTE: V does not have exception handling - this code is unreachable'
			// Comment out the handler body
			for stmt in handler.body {
				result := t.visit_stmt(stmt)
				for line in result.split('\n') {
					buf << '// ${line}'
				}
			}
		}
	}

	if node.finalbody.len > 0 {
		buf << '// finally:'
		for stmt in node.finalbody {
			buf << t.visit_stmt(stmt)
		}
	}

	buf << '// }'

	return buf.join('\n')
}

// Visit Assert
pub fn (mut t VTranspiler) visit_assert(node Assert) string {
	test := t.visit_expr(node.test)
	return 'assert ${test}'
}

// Visit Import
pub fn (mut t VTranspiler) visit_import(node Import) string {
	// Suppress imports - they're handled differently in V
	return ''
}

// Visit ImportFrom
pub fn (mut t VTranspiler) visit_import_from(node ImportFrom) string {
	// Suppress imports
	return ''
}

// Visit Global
pub fn (mut t VTranspiler) visit_global(node Global) string {
	names := node.names.join(', ')
	return "// global ${names}  // V doesn't support global keyword"
}

// Visit Nonlocal
pub fn (mut t VTranspiler) visit_nonlocal(node Nonlocal) string {
	names := node.names.join(', ')
	return "// nonlocal ${names}  // V doesn't support nonlocal keyword"
}

// Visit ExprStmt
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

// Visit Constant
pub fn (mut t VTranspiler) visit_constant(node Constant) string {
	match node.value {
		NoneValue {
			return 'none'
		}
		EllipsisValue {
			return ''
		}
		bool {
			return if node.value as bool { 'true' } else { 'false' }
		}
		int {
			return (node.value as int).str()
		}
		i64 {
			return (node.value as i64).str()
		}
		f64 {
			return (node.value as f64).str()
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

// Visit Name
pub fn (mut t VTranspiler) visit_name(node Name) string {
	// Check if this identifier was escaped due to V built-in type name conflict
	if t.escaped_identifiers[node.id] or { false } {
		return '@${node.id}'
	}
	return escape_keyword(node.id)
}

// Visit BinOp
pub fn (mut t VTranspiler) visit_binop(node BinOp) string {
	left := t.visit_expr(node.left)
	right := t.visit_expr(node.right)
	mut op := op_to_symbol(get_op_type(node.op))

	// Handle power operator specially
	if node.op is Pow {
		return '${left} ^ ${right}'
	}

	// Handle string/list repetition
	if node.op is Mult {
		left_ann := get_expr_annotation(node.left)
		right_ann := get_expr_annotation(node.right)
		if right_ann == 'int' && (left_ann == 'string' || left_ann.starts_with('[]')) {
			return '(${left}.repeat(${right}))'
		}
		// Also check by inferring types when v_annotation is not set
		left_type := t.infer_expr_type(node.left)
		if left_type == 'string' {
			return '(${left}.repeat(${right}))'
		}
		// Check if left is a List literal - list repetition
		if node.left is List {
			return '(${left}.repeat(${right}))'
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
			return '(f64(${left}) ${op} ${right})'
		}
		if (left_ann == 'f64' || left_ann == 'float') && right_ann == 'int' {
			return '(${left} ${op} f64(${right}))'
		}
		// If right is float but left annotation is unknown/empty, wrap left in f64 to be safe
		if (right_ann == 'f64' || right_ann == 'float') && left_ann == '' {
			return '(f64(${left}) ${op} ${right})'
		}
		if (left_ann == 'f64' || left_ann == 'float') && right_ann == '' {
			return '(${left} ${op} f64(${right}))'
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
			return '(${result_type}(${left}) ${op} ${result_type}(${right}))'
		}
		// Cast both to the wider of the two types
		wider := get_wider_type(lann, rann)
		return '(${wider}(${left}) ${op} ${wider}(${right}))'
	}

	return '(${left} ${op} ${right})'
}

// Visit UnaryOp
pub fn (mut t VTranspiler) visit_unaryop(node UnaryOp) string {
	op := op_to_symbol(get_unary_op_type(node.op))
	operand := t.visit_expr(node.operand)

	if node.op is USub {
		// Check if operand is simple
		if node.operand is Call || is_number_expr(node.operand) {
			return '-${operand}'
		}
		return '-(${operand})'
	}

	return '${op}(${operand})'
}

// Visit BoolOp
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

// Visit Compare
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

// Visit Call
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
						return '(${vargs[0]}).str()'
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
				// Convert .format() to string interpolation isn't easy
				// For now, just comment it
				return '${obj} /* .format(${vargs.join(', ')}) not supported */'
			}
			'count' {
				if vargs.len > 0 {
					return '${obj}.count(${vargs[0]})'
				}
				return '0'
			}
			'isdigit' {
				return '${obj}.is_digit()'
			}
			'isalpha' {
				return '${obj}.is_alpha()'
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
				if vargs.len > 0 {
					// Python sort with key/reverse - complex to translate
					return '${obj}.sort(a < b)'
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
				return '${obj} /* .items() - iterate with for k, v in dict */'
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
					return '/* ${obj}.update() - manually merge dicts */'
				}
				return obj
			}
			else {}
		}
	}

	// Check if this is a struct constructor call (known dataclass)
	if fname in t.known_classes {
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
				field_parts << '\t${base_name}: ${base_init}'
			}
		}
		if field_parts.len == 0 {
			return '${fname}{}'
		}
		return '${fname}{\n${field_parts.join('\n')}\n}'
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

fn (t &VTranspiler) build_inline_class_init(class_name string, field_vals map[string]string) string {
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
		if base_init.len > 0 {
			parts << '${base_name}: ${base_init}'
		}
	}
	if parts.len == 0 {
		return ''
	}
	return '${class_name}{${parts.join(', ')}}'
}

fn (t &VTranspiler) resolve_super_base() string {
	if t.current_class_name.len == 0 {
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
	return base
}

fn should_emit_ref_field_type(typ string) bool {
	if typ.len == 0 || typ[0] == `&` {
		return false
	}
	if typ.starts_with('[]') || typ.starts_with('map[') || typ.starts_with('?') {
		return false
	}
	return typ[0] >= `A` && typ[0] <= `Z` && typ != 'Any'
}

fn should_lowercase_call_name(name string, known map[string][]string) bool {
	if name.len == 0 {
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
	if name.len == 0 {
		return name
	}
	first := name[0]
	if first >= `A` && first <= `Z` {
		return (first + 32).ascii_str() + name[1..]
	}
	return name
}

// Visit Attribute
pub fn (mut t VTranspiler) visit_attribute(node Attribute) string {
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

// Visit Subscript
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

// Visit Slice
pub fn (mut t VTranspiler) visit_slice(node Slice) string {
	lower := if l := node.lower { t.visit_expr(l) } else { '' }
	upper := if u := node.upper { t.visit_expr(u) } else { '' }
	return '${lower}..${upper}'
}

// Visit List
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

// Visit Tuple (same as List in V)
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

// Visit Dict
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

// Visit Set (same as List in V)
pub fn (mut t VTranspiler) visit_set(node Set) string {
	mut elts := []string{}
	for e in node.elts {
		elts << t.visit_expr(e)
	}
	return '[${elts.join(', ')}]'
}

// Visit IfExp
pub fn (mut t VTranspiler) visit_ifexp(node IfExp) string {
	test := t.visit_expr(node.test)
	body := t.visit_expr(node.body)
	orelse := t.visit_expr(node.orelse)
	return 'if ${test} { ${body} } else { ${orelse} }'
}

// Visit Lambda
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

// Visit ListComp
pub fn (mut t VTranspiler) visit_list_comp(node ListComp) string {
	// Should be transformed by VComprehensionRewriter
	// Fallback implementation
	return t.visit_generator_exp_impl(node.elt, node.generators)
}

// Visit SetComp
pub fn (mut t VTranspiler) visit_set_comp(node SetComp) string {
	return t.visit_generator_exp_impl(node.elt, node.generators)
}

// Visit DictComp
pub fn (mut t VTranspiler) visit_dict_comp(node DictComp) string {
	mut buf := []string{}
	buf << '(fn () map[string]Any {'
	buf << 'mut result := map[string]Any{}'

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

	return buf.join('\n')
}

// Visit GeneratorExp
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

// Visit Await
pub fn (mut t VTranspiler) visit_await(node Await) string {
	// V doesn't have await, just return the value
	return t.visit_expr(node.value)
}

// Visit Yield
pub fn (mut t VTranspiler) visit_yield(node Yield) string {
	if val := node.value {
		return 'ch <- ${t.visit_expr(val)}'
	}
	return 'ch <- 0'
}

// Visit YieldFrom
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

// Visit FormattedValue
pub fn (mut t VTranspiler) visit_formatted_value(node FormattedValue) string {
	expr := t.visit_expr(node.value)
	return '(${expr}).str()'
}

// Visit JoinedStr (f-string)
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

// Visit NamedExpr (walrus operator - should be transformed)
// When used standalone, just emit as assignment expression
pub fn (mut t VTranspiler) visit_named_expr(node NamedExpr) string {
	target := t.visit_expr(node.target)
	value := t.visit_expr(node.value)
	return '(${target} := ${value})'
}

// Check if a Compare expression has a NamedExpr (walrus) as its left operand
fn has_walrus_in_compare(test Expr) bool {
	if test is Compare {
		cmp := test as Compare
		if cmp.left is NamedExpr {
			return true
		}
	}
	return false
}

// Extract walrus assignment and modified test from a Compare with NamedExpr
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

// Visit Starred
pub fn (mut t VTranspiler) visit_starred(node Starred) string {
	return '...${t.visit_expr(node.value)}'
}

// Helper: get typename from annotation expression
pub fn (mut t VTranspiler) typename_from_annotation(ann Expr) string {
	match ann {
		Name {
			name := ann.id
			if name in v_type_map {
				return v_type_map[name]
			}
			return name
		}
		Subscript {
			value := t.typename_from_annotation(ann.value)
			index := t.typename_from_annotation(ann.slice)

			mapped := v_container_type_map[value] or { value }
			if value == 'Tuple' {
				return '(${index})'
			}
			if value == 'Dict' {
				// Handle Dict[K, V]
				return 'map[${index}]'
			}
			return '${mapped}${index}'
		}
		Tuple {
			mut types := []string{}
			for e in ann.elts {
				types << t.typename_from_annotation(e)
			}
			return types.join(', ')
		}
		Attribute {
			// Handle typing.X or similar qualified names
			// e.g., typing.List -> List
			attr := ann.attr
			if attr in v_type_map {
				return v_type_map[attr]
			}
			if attr in v_container_type_map {
				return v_container_type_map[attr]
			}
			return attr
		}
		Constant {
			if ann.value is string {
				return ann.value as string
			}
			return default_type
		}
		else {
			return default_type
		}
	}
}

// Helper: infer generator yield type
fn (mut t VTranspiler) infer_generator_yield_type(node FunctionDef) string {
	// Walk the function body to find yield statements
	// For simplicity, return "Any" for now
	// A proper implementation would analyze yield expressions
	return 'Any'
}

// Helper functions
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

fn get_next_generic(existing []string) string {
	for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.bytes() {
		s := c.ascii_str()
		if s !in existing {
			return s
		}
	}
	return 'T'
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

fn is_number_expr(expr Expr) bool {
	if expr is Constant {
		c := expr as Constant
		return c.value is int || c.value is i64 || c.value is f64
	}
	return false
}

// Infer the type of an expression for variable tracking
fn (t &VTranspiler) infer_expr_type(expr Expr) string {
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
			// Propagate known type
			known := t.var_types[expr.id]
			if known.len > 0 {
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
			if left_type.len > 0 && right_type.len > 0 {
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
				if key_type.len == 0 {
					key_type = 'string'
				}
				if val_type.len == 0 {
					val_type = 'Any'
				}
				return 'map[${key_type}]${val_type}'
			}
			return ''
		}
		Subscript {
			// Check v_annotation on the subscript
			ann := get_expr_annotation(expr)
			if ann.len > 0 {
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
			if ann.len > 0 {
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
			if fname.len > 0 {
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
fn (t &VTranspiler) infer_return_type(stmts []Stmt) string {
	mut ret_type := ''
	for stmt in stmts {
		match stmt {
			Return {
				if val := stmt.value {
					mut inferred := t.infer_expr_type(val)
					// Fallback: check v_annotation from the frontend
					if inferred.len == 0 {
						inferred = get_expr_annotation(val)
					}
					if inferred.len > 0 && inferred != 'none' {
						// Map Python type names to V types
						inferred = match inferred {
							'float' { 'f64' }
							'str' { 'string' }
							else { inferred }
						}
						if ret_type.len == 0 {
							ret_type = inferred
						}
						// If we get conflicting types, keep the first non-empty one
					}
				}
			}
			If {
				sub := t.infer_return_type(stmt.body)
				if sub.len > 0 && ret_type.len == 0 {
					ret_type = sub
				}
				sub2 := t.infer_return_type(stmt.orelse)
				if sub2.len > 0 && ret_type.len == 0 {
					ret_type = sub2
				}
			}
			For {
				sub := t.infer_return_type(stmt.body)
				if sub.len > 0 && ret_type.len == 0 {
					ret_type = sub
				}
			}
			While {
				sub := t.infer_return_type(stmt.body)
				if sub.len > 0 && ret_type.len == 0 {
					ret_type = sub
				}
			}
			Try {
				sub := t.infer_return_type(stmt.body)
				if sub.len > 0 && ret_type.len == 0 {
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
						if inferred.len > 0 {
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
					if type_str.len > 0 {
						t.var_types[n.id] = type_str
					}
				}
			}
			AugAssign {
				// Track augmented assignment types (e.g., total += n preserves type)
				if stmt.target is Name {
					n := stmt.target as Name
					existing := t.var_types[n.id]
					if existing.len == 0 {
						inferred := t.infer_expr_type(stmt.value)
						if inferred.len > 0 {
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
						if ret_type.len > 0 {
							t.func_return_types[stmt.name] = ret_type
						}
					}
				}
			}
			else {}
		}
	}
}
