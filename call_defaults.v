module main

// Only an unconditional import with no other binding in the file can name this function.
fn imported_default_names(node Module, bindings map[string]int) map[string]bool {
	mut names := map[string]bool{}
	if bindings['*'] > 0 { return names }
	for stmt in node.body {
		if stmt is ImportFrom {
			for alias in stmt.names {
				name := alias.asname or { alias.name }
				if bindings[name] == 1 { names[name] = true }
			}
		}
	}
	return names
}

fn register_defaulted_functions(parsed map[string]Module, mut registry ModuleRegistry) {
	for key, node in parsed {
		mut names := map[string]int{}
		mut sites := []BindingCall{}
		count_call_bindings(node, mut names, mut sites, false)
		for stmt in node.body {
			if stmt !is FunctionDef { continue }
			sig := stmt as FunctionDef
			if names[sig.name] != 1 || names['*'] > 0 || sig.decorator_list.len > 0
				|| sig.is_generator || sig.is_class_method || sig.name in call_dispatch_names
				|| sig.args.vararg != none || sig.args.kwarg != none
				|| sig.args.kwonlyargs.len > 0 || sig.args.posonlyargs.len > 0
				|| sig.args.defaults.len == 0 {
				continue
			}
			if sig.args.args.any(it.arg in ['self', 'cls']) { continue }
			mut eligible := true
			for param in sig.args.args {
				if param.arg in sig.mutable_vars && !is_value_param(param) {
					mut reader := new_transpiler()
					if param.arg in sig.condition_walrus_names
						|| !is_optional_value_type(reader.init_parameter_type(param, false)) {
						eligible = false
					}
				}
			}
			if eligible { registry.defaulted_functions['${key}.${sig.name}'] = sig }
		}
	}
}

fn (t VTranspiler) imported_default_signature(path string) ?FunctionDef {
	mut target := path
	mut seen := map[string]bool{}
	for _ in 0 .. max_reexport_hops {
		if target == '' || seen[target] { return none }
		seen[target] = true
		info := t.registry.lookup(target.all_before_last('.'))
		if info.dotted == '' { return none }
		canonical := '${info.dotted}.${target.all_after_last('.')}'
		if binding := t.registry.init_import_bindings[canonical] {
			target = binding
			continue
		}
		return t.registry.defaulted_functions[canonical] or { return none }
	}
	return none
}

fn parameter_is_dynamic(param Arg) bool {
	if ann := param.annotation {
		expr := *ann
		return match expr {
			Name { expr.id in ['Any', 'object'] }
			Attribute { expr.attr == 'Any' }
			else { false }
		}
	}
	return param.v_annotation in ['', 'Any', 'object']
}

// Keep integer defaults in integer storage and reject unsupported scalar forms.
fn imported_literal_default(expr Expr) bool {
	if !call_literal_default(expr) { return false }
	value := if expr is UnaryOp { *expr.operand } else { expr }
	if value is Constant {
		if value.value is ComplexValue { return false }
		return (value.v_annotation or { '' }) != 'int'
			|| value.value is int || value.value is i64
	}
	return false
}

// Python annotations do not coerce a default's type. V must not widen an int to a float here.
fn imported_default_matches_parameter(param Arg, expr Expr) bool {
	mut reader := new_transpiler()
	typ := reader.init_parameter_type(param, false)
	if typ in ['Any', '?Any'] { return true }
	value := if expr is UnaryOp { *expr.operand } else { expr }
	if value is Constant {
		if value.value is NoneValue { return typ.starts_with('?') }
		base := typ.trim_left('?')
		return match value.value {
			int, i64 { base in ['int', 'i64'] }
			f64 { base == 'f64' }
			bool { base == 'bool' }
			string { base == 'string' }
			else { false }
		}
	}
	return false
}

fn (mut t VTranspiler) complete_imported_call(node Call) ?Call {
	if !t.emit_pub || node.func !is Name || node.args.any(it is Starred) {
		return none
	}
	name := (node.func as Name).id
	if !t.default_import_names[name] { return none }
	sig := t.imported_default_signature(t.init_python_path(node.func)) or { return none }
	if name != sig.name { return none }
	params := sig.args.args
	first_default := params.len - sig.args.defaults.len
	// Fully supplied calls retain the existing emission, including its keyword guards.
	if node.args.len + node.keywords.len >= params.len { return none }
	mut keyword_values := map[int]Expr{}
	mut previous := node.args.len - 1
	for keyword in node.keywords {
		keyword_name := keyword.arg or { return none }
		mut position := -1
		for i, param in params {
			if param.arg == keyword_name {
				position = i
				break
			}
		}
		// Inserting literal defaults may not reorder or duplicate supplied expressions.
		if position <= previous { return none }
		previous = position
		keyword_values[position] = keyword.value
	}
	mut completed := node.args.clone()
	mut needs_pyrt := false
	for i in node.args.len .. params.len {
		if supplied := keyword_values[i] {
			completed << supplied
			continue
		}
		if i < first_default { return none }
		value := sig.args.defaults[i - first_default]
		if !imported_literal_default(value)
			|| !imported_default_matches_parameter(params[i], value) {
			return none
		}
		if value is Constant && value.value is NoneValue && parameter_is_dynamic(params[i]) {
			needs_pyrt = true
			runtime := Expr(Name{ id: 'pyrt' })
			completed << Attribute{ value: &runtime, attr: 'none_' }
		} else {
			completed << value
		}
	}
	if needs_pyrt { t.add_using('pyrt') }
	return Call{ ...node, args: completed, keywords: []Keyword{} }
}
