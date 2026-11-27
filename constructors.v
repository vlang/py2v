module main

// InitConstructor keeps the written initializer with the class it belongs to.
// The package scan fills this before any file is emitted; fields alone cannot
// describe what constructing a Python object does.
struct InitConstructor {
	class_name             string
	factory_name           string
	method_name            string
	defining_module        string
	init                   FunctionDef
	unsupported            string
	unresolved_init_fields []string
	type_params            []string
}

// A mandatory reference cannot be left unset while the initializer runs.
// Keep this limitation at the construction site instead of adding an invalid
// zero literal to every otherwise harmless class definition.
fn init_required_reference_fields(node ClassDef, classes map[string]ClassDef, mut seen map[string]bool) []string {
	if seen[node.name] { return []string{} }
	seen[node.name] = true
	mut fields := []string{}
	for field, raw_type in node.declarations {
		if field in python_dunder_class_attrs || field in node.class_defaults { continue }
		mut typ := map_type(raw_type)
		if typ in classes {
			typ = emitted_class_name(typ)
		}
		// A field of one of the class's own type parameters is a value of that type.
		if typ in node.type_params || raw_type in node.type_params {
			continue
		}
		if (typ.starts_with('&') && !typ.starts_with('&pyrt.ListRef[')) || should_emit_ref_field_type(typ) {
			fields << field
		}
	}
	for base in node.bases {
		if base is Name {
			if parent := classes[base.id] {
				for field in init_required_reference_fields(parent, classes, mut seen) {
					fields << '${base.id}_${field}'
				}
			}
		}
	}
	return fields
}

fn init_positional_parameters(info InitConstructor) []Arg {
	mut params := info.init.args.posonlyargs.clone()
	params << info.init.args.args
	if params.len > 0 {
		return params[1..].clone()
	}
	return []Arg{}
}

fn init_parameters(info InitConstructor) []Arg {
	mut params := init_positional_parameters(info)
	params << info.init.args.kwonlyargs
	return params
}

fn init_signature_error(info InitConstructor) string {
	if info.unsupported != '' {
		return info.unsupported
	}
	if info.unresolved_init_fields.len > 0 {
		return 'unknown_field_type_' + info.unresolved_init_fields.join('_')
	}
	mut positional := info.init.args.posonlyargs.clone()
	positional << info.init.args.args
	if positional.len == 0 || positional[0].arg != 'self' {
		return 'receiver_must_be_self'
	}
	if info.init.decorator_kind != '' || info.init.is_generator {
		return 'decorated_or_generator_initializer'
	}
	if info.init.args.vararg != none || info.init.args.kwarg != none {
		return 'variadic_initializer'
	}
	for param in info.init.args.kwonlyargs {
		if param.arg in info.init.mutable_vars {
			return 'mutable_keyword_only_parameter_' + param.arg
		}
	}
	return ''
}

// Use a deliberately unresolved function at the use site. This prevents an
// unsupported constructor from silently returning a partly initialized value,
// while a class which is only defined need not gain a new compilation failure.
fn (mut t VTranspiler) init_constructor_error(info InitConstructor, reason string) string {
	mut label := 'unsupported_init_${info.class_name}_${reason}_'.to_lower()
	mut chars := []u8{}
	for c in label.bytes() {
		chars << if (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `_` {
			c
		} else {
			`_`
		}
	}
	label = chars.bytestr()
	return '${t.new_tmp(label)}()'
}

fn (mut t VTranspiler) resolved_init_parameter_type(param Arg, keyword_only bool) string {
	mut typ := ''
	if ann := param.annotation {
		typ = t.typename_from_annotation(*ann)
		if typ == '' && keyword_only {
			typ = '?Any'
		}
	}
	// This is the same fallback as visit_function_def. That emitter currently
	// uses frontend parameter inference only for ordinary parameters.
	if typ == '' && !keyword_only && param.v_annotation != '' {
		typ = t.map_type(param.v_annotation)
	}
	if typ == '' {
		return 'Any'
	}
	return typ
}

fn (mut t VTranspiler) init_param_is_v_mut(info InitConstructor, param Arg, keyword_only bool) bool {
	typ := t.resolved_init_parameter_type(param, keyword_only)
	return param_mut_mode(info.init, param, typ, true) == .v_mut_param
}

fn (mut t VTranspiler) init_parameter_type(param Arg, keyword_only bool) string {
	typ := t.resolved_init_parameter_type(param, keyword_only)
	if typ == 'Any' && param.annotation == none && (keyword_only || param.v_annotation == '') {
		t.generated_code_has_any_type = true
	}
	return typ
}

fn (mut t VTranspiler) emit_init_factory(info InitConstructor) string {
	if init_signature_error(info) != '' {
		return ''
	}
	params := init_parameters(info)
	positional_count := init_positional_parameters(info).len
	mut declarations := []string{}
	mut forwarded := []string{}
	mut names := map[string]bool{}
	for i, param in params {
		keyword_only := i >= positional_count
		name := if keyword_only {
			escape_identifier(param.arg)
		} else {
			escape_local_decl(param.arg)
		}
		names[name] = true
		typ := t.init_parameter_type(param, keyword_only)
		if t.init_param_is_v_mut(info, param, keyword_only) {
			declarations << 'mut ${name} ${typ}'
			forwarded << 'mut ${name}'
		} else {
			declarations << '${name} ${typ}'
			forwarded << name
		}
	}
	mut instance := 'py2v_instance'
	mut suffix := 0
	for (instance in names) {
		suffix++
		instance = 'py2v_instance_${suffix}'
	}
	mut class_type := t.local_class_name(info.class_name)
	mut factory := info.factory_name
	if info.type_params.len > 0 {
		generics := '[${info.type_params.join(', ')}]'
		class_type += generics
		factory += generics
	}
	// A class held by reference is made on the heap and returned by reference.
	ref := if info.class_name in t.ref_classes { '&' } else { '' }
	return 'pub fn ${factory}(${declarations.join(', ')}) ${ref}${class_type} {\n' +
		'\tmut ${instance} := ${ref}${class_type}{}\n' +
		'\t${instance}.${info.method_name}(${forwarded.join(', ')})\n' +
		'\treturn ${instance}\n}'
}

// Unlike an expression referring to a Python name or calling a function, an
// immutable scalar expression cannot observe a later change to the defining
// scope or allocate a shared default object. Reusing the existing expression
// emitter at the call site is therefore safe for these defaults.
fn init_immutable_default(expr Expr) bool {
	return match expr {
		Constant { call_literal_default(expr) }
		UnaryOp { init_immutable_default(expr.operand) }
		BinOp { init_immutable_default(expr.left) && init_immutable_default(expr.right) }
		else { false }
	}
}

// The binding rules match bind_module_call: ordinary and keyword-only
// parameters and duplicate detection, with immutable scalar defaults. A rejected binding
// must remain an error rather than falling back to a field-order literal.
fn (mut t VTranspiler) render_init_call(info InitConstructor, qualified_factory string, node Call) string {
	reason := init_signature_error(info)
	if reason != '' {
		return t.init_constructor_error(info, reason)
	}
	positional := init_positional_parameters(info)
	params := init_parameters(info)
	if node.args.len > positional.len {
		return t.init_constructor_error(info, 'too_many_positional_arguments')
	}
	mut defaults := map[string]Expr{}
	mut original_positional := info.init.args.posonlyargs.clone()
	original_positional << info.init.args.args
	for i, expr in info.init.args.defaults {
		index := original_positional.len - info.init.args.defaults.len + i
		if index > 0 {
			defaults[original_positional[index].arg] = expr
		}
	}
	for i, expr in info.init.args.kw_defaults {
		if value := expr {
			defaults[info.init.args.kwonlyargs[i].arg] = value
		}
	}
	mut supplied := map[string]Expr{}
	mut order := []string{}
	for i, expr in node.args {
		if expr is Starred {
			return t.init_constructor_error(info, 'starred_arguments')
		}
		param := positional[i].arg
		supplied[param] = expr
		order << param
	}
	param_names := params.map(it.arg)
	posonly_names := info.init.args.posonlyargs.map(it.arg)
	for keyword in node.keywords {
		param := keyword.arg or { return t.init_constructor_error(info, 'expanded_keywords') }
		if param !in param_names {
			return t.init_constructor_error(info, 'unknown_keyword_' + param)
		}
		if param in posonly_names {
			return t.init_constructor_error(info, 'positional_only_keyword_' + param)
		}
		if param in supplied {
			return t.init_constructor_error(info, 'duplicate_argument_' + param)
		}
		supplied[param] = keyword.value
		order << param
	}
	mut bound := []Expr{}
	for param in params {
		if expr := supplied[param.arg] {
			bound << expr
		} else {
			expr := defaults[param.arg] or {
				return t.init_constructor_error(info, 'missing_argument_' + param.arg)
			}
			if !init_immutable_default(expr) {
				return t.init_constructor_error(info, 'nonliteral_default_' + param.arg)
			}
			bound << expr
		}
	}
	mut needs_sequence := false
	if order.len > 1 {
		for expr in supplied.values() {
			if !init_argument_is_simple(expr) { needs_sequence = true }
		}
	}
	if needs_sequence {
		return t.render_sequenced_init_call(info, qualified_factory, params, supplied, order, bound)
	}
	mut rendered := []string{}
	positional_count := positional.len
	for i, expr in bound {
		mut value := t.render_init_argument(expr, params[i])
		if t.init_param_is_v_mut(info, params[i], i >= positional_count) {
			value = 'mut ${value}'
		}
		rendered << value
	}
	return '${qualified_factory}(${rendered.join(', ')})'
}

fn (mut t VTranspiler) render_init_argument(expr Expr, param Arg) string {
	if proven_word_parameter(param) {
		return t.visit_integer_boundary(expr, .scalar_argument, 'u64')
	}
	return t.typed_literal_arg(expr)
}

// A function call's arguments need explicit sequencing: the C backend may
// evaluate them right to left. Names and immutable literals alone cannot
// observe that ordering, so the common field-forwarding call stays compact.
fn init_argument_is_simple(expr Expr) bool {
	return expr is Name || init_immutable_default(expr)
}

struct InitArgumentRefs {
mut:
	names  map[string]Name
	calls  []Call
	scoped bool
}

fn collect_init_argument_refs[T](node T, mut refs InitArgumentRefs) {
	$if T is Lambda || T is ListComp || T is SetComp || T is DictComp || T is GeneratorExp || T is NamedExpr {
		refs.scoped = true
		return
	}
	$if T is Name {
		refs.names[node.id] = node
	}
	$if T is Call {
		refs.calls << node
	}
	$if T is $option {
		if value := node { collect_init_argument_refs(value, mut refs) }
	} $else $if T is $pointer {
		collect_init_argument_refs(*node, mut refs)
	} $else $if T is $array {
		for value in node { collect_init_argument_refs(value, mut refs) }
	} $else $if T is $sumtype {
		$for variant in T.variants {
			if node is variant { collect_init_argument_refs(node, mut refs) }
		}
	} $else $if T is $struct {
		$for field in T.fields {
			collect_init_argument_refs(node.$(field.name), mut refs)
		}
	}
}

// The ordinary emitter does not retain every kind of parameter in its local
// spelling map. Constructor IIFEs still need to capture keyword-only and
// variadic parameters, as well as names of local function values.
fn init_function_capture_names(node FunctionDef) map[string]bool {
	mut names := map[string]bool{}
	mut params := node.args.posonlyargs.clone()
	params << node.args.args
	params << node.args.kwonlyargs
	for param in params { names[param.arg] = true }
	if param := node.args.vararg { names[param.arg] = true }
	if param := node.args.kwarg { names[param.arg] = true }
	return names
}

fn (t VTranspiler) init_argument_local(name Name) bool {
	if t.global_vars[name.id] { return false }
	return name.id in t.init_capture_locals || name.id in t.local_idents || t.is_bound_in_scope(name.id)
		|| name.id in t.loop_idents || t.binding_spelling(name.id) in t.loop_idents
		|| name.id in t.renamed_idents
		|| (name.id == 'self' && t.current_class_name != '' && !t.current_classmethod)
}

fn (mut t VTranspiler) init_mutated_argument_names(calls []Call) map[string]bool {
	mut names := map[string]bool{}
	for call in calls {
		if constructor := t.resolve_init_constructor(call.func) {
			params := init_positional_parameters(constructor)
			for i, arg in call.args {
				if i < params.len && t.init_param_is_v_mut(constructor, params[i], false)
					&& arg is Name {
					names[arg.id] = true
				}
			}
			all_params := init_parameters(constructor)
			pos_count := params.len
			for keyword in call.keywords {
				if name := keyword.arg {
					if keyword.value is Name {
						for idx, p in all_params {
							if p.arg == name
								&& t.init_param_is_v_mut(constructor, p, idx >= pos_count) {
								names[(keyword.value as Name).id] = true
								break
							}
						}
					}
				}
			}
		} else if call.func is Name {
			indices := t.mut_param_indices[(call.func as Name).id] or { []int{} }
			for i in indices {
				if i < call.args.len && call.args[i] is Name {
					names[(call.args[i] as Name).id] = true
				}
			}
		}
		if call.func is Attribute {
			attr := call.func as Attribute
			if attr.value is Name {
				receiver := (attr.value as Name).id
				class_name := if receiver == 'self' {
					t.current_class_name
				} else {
					t.var_types[receiver]
				}
				if t.mut_receiver_methods['${class_name}_${attr.attr}']
					|| attr.attr in ['append', 'extend', 'insert', 'remove', 'pop', 'clear', 'sort',
						'reverse', 'update', 'add', 'discard', 'setdefault', 'popitem'] {
					names[receiver] = true
				}
			}
		}
	}
	return names
}

fn (mut t VTranspiler) render_sequenced_init_call(info InitConstructor, qualified_factory string,
	params []Arg, supplied map[string]Expr, order []string, bound []Expr) string {
	if info.type_params.len > 0 {
		return t.init_constructor_error(info, 'sequenced_generic_arguments')
	}
	mut refs := InitArgumentRefs{}
	for name in order {
		expr := supplied[name] or { return t.init_constructor_error(info, 'missing_bound_argument_' + name) }
		collect_init_argument_refs(expr, mut refs)
	}
	if refs.scoped {
		return t.init_constructor_error(info, 'scoped_argument_expression')
	}
	mut mutated := t.init_mutated_argument_names(refs.calls)
	positional_count := init_positional_parameters(info).len
	for i, param in params {
		if t.init_param_is_v_mut(info, param, i >= positional_count) {
			if expr := supplied[param.arg] {
				if expr is Name {
					mutated[expr.id] = true
				} else {
					return t.init_constructor_error(info, 'mutable_argument_expression_' + param.arg)
				}
			}
		}
	}
	mut captures := []string{}
	mut declarations := []string{}
	mut actuals := []string{}
	mut ref_names := refs.names.keys()
	ref_names.sort()
	for raw_name in ref_names {
		name := refs.names[raw_name]
		if !t.init_argument_local(name) { continue }
		emitted := t.visit_name(name)
		if emitted.starts_with('(*') && emitted.ends_with(')') {
			// Nested functions share this binding through a storage pointer.
			// Capture that pointer; argument reads and mutations still dereference it.
			captures << emitted[2..emitted.len - 1]
		} else if mutated[raw_name] {
			mut typ := t.infer_expr_type(Expr(name))
			if typ == '' {
				if annotation := name.v_annotation { typ = t.map_type(annotation) }
			}
			if typ == '' && raw_name == 'self' { typ = t.local_class_name(t.current_class_name) }
			if typ == '' || typ == 'auto' {
				return t.init_constructor_error(info, 'unknown_mutable_capture_type_' + raw_name)
			}
			declarations << 'mut ${emitted} ${typ}'
			actuals << 'mut ${emitted}'
		} else {
			captures << emitted
		}
	}
	mut lines := []string{}
	mut evaluated := map[string]string{}
	param_names := params.map(it.arg)
	for name in order {
		expr := supplied[name] or { return t.init_constructor_error(info, 'missing_bound_argument_' + name) }
		index := param_names.index(name)
		value := t.render_init_argument(expr, params[index])
		if init_immutable_default(expr)
			|| t.init_param_is_v_mut(info, params[index], index >= positional_count) {
			evaluated[name] = value
		} else {
			tmp := t.new_tmp('init_arg')
			lines << '\t${tmp} := ${value}'
			evaluated[name] = tmp
		}
	}
	mut rendered := []string{}
	for i, param in params {
		mut value := evaluated[param.arg] or { t.render_init_argument(bound[i], param) }
		if t.init_param_is_v_mut(info, param, i >= positional_count) { value = 'mut ${value}' }
		rendered << value
	}
	lines << '\treturn ${qualified_factory}(${rendered.join(', ')})'
	capture_list := if captures.len > 0 { ' [${captures.join(', ')}]' } else { '' }
	mut result_type := if info.defining_module != '' {
		t.registry.class_names['${info.defining_module}.${info.class_name}'] or {
			emitted_class_name(info.class_name)
		}
	} else {
		t.local_class_name(info.class_name)
	}
	if qualified_factory.contains('.') {
		result_type = qualified_factory.all_before_last('.') + '.' + result_type
	}
	return '(fn${capture_list} (${declarations.join(', ')}) ${result_type} {\n' +
		lines.join('\n') + '\n})(${actuals.join(', ')})'
}
