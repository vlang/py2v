module main

fn defaults_test_transpiler() VTranspiler {
	mut t := new_transpiler()
	t.emit_pub = true
	t.default_import_names['greet'] = true
	t.registry.add_module(PyModuleInfo{ dotted: 'pkg.provider', v_module: 'py_pkg' })
	t.init_import_aliases['greet'] = 'pkg.provider.greet'
	t.registry.defaulted_functions['pkg.provider.greet'] = FunctionDef{
		name: 'greet'
		args: Arguments{
			args:     [Arg{ arg: 'value' }, Arg{ arg: 'suffix' }]
			defaults: [Expr(Constant{ value: '!' })]
		}
	}
	return t
}

fn defaults_test_call() Call {
	callee := Expr(Name{ id: 'greet' })
	return Call{ func: &callee, args: [Expr(Constant{ value: 7 })] }
}

fn test_imported_default_appends_without_changing_supplied_argument() {
	mut t := defaults_test_transpiler()
	assert t.visit_call(defaults_test_call()) == "greet(7, '!')"
}

fn test_imported_any_default_uses_runtime_none() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args.defaults = [Expr(Constant{ value: NoneValue{} })]
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.visit_call(defaults_test_call()) == 'greet(7, pyrt.none_)'
	assert 'pyrt' in t.usings
}

fn test_imported_defaults_leave_keywords_and_unpacking_unchanged() {
	mut t := defaults_test_transpiler()
	base := defaults_test_call()
	assert t.complete_imported_call(Call{ ...base, keywords: [Keyword{ arg: 'suffix', value: Constant{ value: '?' } }] }) == none
	value := Expr(Name{ id: 'values' })
	assert t.complete_imported_call(Call{ ...base, args: [Expr(Starred{ value: &value })] }) == none
}

fn test_imported_ordered_keyword_supplies_a_required_parameter() {
	mut t := defaults_test_transpiler()
	base := defaults_test_call()
	assert t.visit_call(Call{
		...base
		args:     []Expr{}
		keywords: [Keyword{ arg: 'value', value: Constant{ value: 7 } }]
	}) == "greet(7, '!')"
}

fn test_imported_keyword_defaults_preserve_supplied_expression_order() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args = Arguments{
		args:     [Arg{ arg: 'first' }, Arg{ arg: 'middle' }, Arg{ arg: 'last' }]
		defaults: [Expr(Constant{ value: 2 }), Expr(Constant{ value: 3 })]
	}
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	mark := Expr(Name{ id: 'mark' })
	first := Call{ func: &mark, args: [Expr(Constant{ value: 1 })] }
	last := Call{ func: &mark, args: [Expr(Constant{ value: 9 })] }
	assert t.visit_call(Call{
		...defaults_test_call()
		args:     []Expr{}
		keywords: [Keyword{ arg: 'first', value: first }, Keyword{ arg: 'last', value: last }]
	}) == 'greet(mark(1), 2, mark(9))'
}

fn test_imported_keywords_reject_reordering_duplicates_and_unknown_bindings() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args = Arguments{
		args:     [Arg{ arg: 'first' }, Arg{ arg: 'middle' }, Arg{ arg: 'last' }]
		defaults: [Expr(Constant{ value: 2 }), Expr(Constant{ value: 3 })]
	}
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	value := Expr(Constant{ value: 7 })
	invalid := [
		[Keyword{ arg: 'last', value: value }, Keyword{ arg: 'first', value: value }],
		[Keyword{ arg: 'first', value: value }, Keyword{ arg: 'first', value: value }],
		[Keyword{ arg: 'unknown', value: value }],
		[Keyword{ arg: 'last', value: value }],
		[Keyword{ value: value }],
	]
	for keywords in invalid {
		assert t.complete_imported_call(Call{
			...defaults_test_call()
			args:     []Expr{}
			keywords: keywords
		}) == none
	}
	assert t.complete_imported_call(Call{
		...defaults_test_call()
		keywords: [Keyword{ arg: 'first', value: value }]
	}) == none
}

fn test_imported_defaults_leave_full_and_excess_calls_unchanged() {
	mut t := defaults_test_transpiler()
	base := defaults_test_call()
	assert t.complete_imported_call(Call{
		...base
		args: [Expr(Constant{ value: 1 }), Expr(Constant{ value: 2 })]
	}) == none
	assert t.complete_imported_call(Call{
		...base
		args: [Expr(Constant{ value: 1 }), Expr(Constant{ value: 2 }), Expr(Constant{ value: 3 })]
	}) == none
}

fn test_imported_defaults_do_not_fill_missing_required_arguments() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args.args << Arg{ arg: 'last' }
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.complete_imported_call(defaults_test_call()) == none
}

fn test_imported_defaults_leave_definition_time_expressions_unchanged() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args.defaults = [Expr(Name{ id: 'shared_default' })]
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.complete_imported_call(defaults_test_call()) == none
}

fn test_imported_defaults_leave_shadowed_and_aliased_names_unchanged() {
	mut t := defaults_test_transpiler()
	t.local_idents['greet'] = 'greet'
	assert t.complete_imported_call(defaults_test_call()) == none
	t.local_idents.clear()
	t.init_import_aliases['renamed'] = 'pkg.provider.greet'
	callee := Expr(Name{ id: 'renamed' })
	assert t.complete_imported_call(Call{ ...defaults_test_call(), func: &callee }) == none
}

fn test_imported_defaults_do_not_change_single_file_calls() {
	mut t := defaults_test_transpiler()
	t.emit_pub = false
	assert t.complete_imported_call(defaults_test_call()) == none
}

fn test_imported_defaults_require_an_unconditional_unshadowed_import() {
	imported := Stmt(ImportFrom{ mod: 'pkg.provider', names: [Alias{ name: 'greet' }] })
	node := Module{ body: [imported] }
	assert imported_default_names(node, {
		'greet': 1
	})['greet']
	assert imported_default_names(node, {
		'greet': 2
	}).len == 0
	assert imported_default_names(node, {
		'greet': 1
		'*':     1
	}).len == 0
	condition := Expr(Constant{ value: false })
	conditional := Module{ body: [Stmt(If{ test: &condition, body: [imported] })] }
	assert imported_default_names(conditional, {
		'greet': 1
	}).len == 0
	mut t := defaults_test_transpiler()
	t.default_import_names.clear()
	assert t.complete_imported_call(defaults_test_call()) == none
}

fn test_imported_defaults_reject_inexact_integer_and_complex_literals() {
	large := Expr(Constant{ value: f64(1e30), v_annotation: 'int' })
	assert !imported_literal_default(large)
	assert !imported_literal_default(UnaryOp{ op: USub{}, operand: &large })
	assert !imported_literal_default(Constant{ value: ComplexValue{} })
	assert imported_literal_default(Constant{ value: 7, v_annotation: 'int' })
	assert imported_literal_default(Constant{ value: f64(1.5), v_annotation: 'float' })
}

fn test_imported_defaults_do_not_coerce_python_scalar_kinds() {
	float_type := Expr(Name{ id: 'float' })
	int_type := Expr(Name{ id: 'int' })
	float_param := Arg{ arg: 'scale', annotation: &float_type }
	int_param := Arg{ arg: 'count', annotation: &int_type }
	integer := Expr(Constant{ value: 1, v_annotation: 'int' })
	floating := Expr(Constant{ value: f64(1.0), v_annotation: 'float' })
	assert !imported_default_matches_parameter(float_param, integer)
	assert !imported_default_matches_parameter(int_param, floating)
	assert imported_default_matches_parameter(float_param, floating)
	assert imported_default_matches_parameter(int_param, integer)
	assert imported_default_matches_parameter(Arg{ arg: 'dynamic' }, integer)
}

fn test_rejected_imported_defaults_do_not_add_imports() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args.defaults = [Expr(Constant{ value: NoneValue{} }), Expr(Name{ id: 'shared' })]
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.complete_imported_call(Call{ ...defaults_test_call(), args: []Expr{} }) == none
	assert t.usings.len == 0
}

fn test_imported_default_registry_excludes_unsupported_signatures() {
	t := defaults_test_transpiler()
	sig := t.registry.defaulted_functions['pkg.provider.greet']
	mut accepted := new_module_registry()
	register_defaulted_functions({
		'pkg.provider': Module{ body: [Stmt(sig)] }
	}, mut accepted)
	assert accepted.defaulted_functions.len == 1
	unsupported := [
		FunctionDef{ ...sig, is_generator: true },
		FunctionDef{ ...sig, decorator_list: [Expr(Name{ id: 'decorator' })] },
		FunctionDef{ ...sig, args: Arguments{ ...sig.args, vararg: Arg{ arg: 'extra' } } },
		FunctionDef{ ...sig, args: Arguments{ ...sig.args, kwarg: Arg{ arg: 'options' } } },
		FunctionDef{ ...sig, args: Arguments{ ...sig.args, kwonlyargs: [Arg{ arg: 'option' }] } },
		FunctionDef{ ...sig, args: Arguments{ ...sig.args, posonlyargs: [Arg{ arg: 'position' }] } },
		FunctionDef{ ...sig, mutable_vars: ['value'] },
		FunctionDef{
			...sig
			args: Arguments{
				...sig.args
				args: [Arg{ arg: 'self' }, Arg{ arg: 'suffix' }]
			}
		},
	]!
	for invalid in unsupported {
		mut rejected := new_module_registry()
		register_defaulted_functions({
			'pkg.provider': Module{ body: [Stmt(invalid)] }
		}, mut rejected)
		assert rejected.defaulted_functions.len == 0
	}
}

fn test_optional_scalar_defaults_allow_local_rebinding() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	text := Expr(Name{ id: 'str' })
	nothing := Expr(Constant{ value: NoneValue{} })
	annotation := Expr(BinOp{ left: &text, op: BitOr{}, right: &nothing })
	sig.args.args[1].annotation = &annotation
	sig.args.defaults = [nothing]
	sig.mutable_vars = ['suffix']
	mut registry := new_module_registry()
	register_defaulted_functions({
		'pkg.provider': Module{ body: [Stmt(sig)] }
	}, mut registry)
	assert registry.defaulted_functions.len == 1
	t.registry.defaulted_functions = registry.defaulted_functions
	assert t.visit_call(defaults_test_call()) == 'greet(7, none)'
}

fn test_optional_walrus_parameters_remain_excluded() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	text := Expr(Name{ id: 'str' })
	nothing := Expr(Constant{ value: NoneValue{} })
	annotation := Expr(BinOp{ left: &text, op: BitOr{}, right: &nothing })
	sig.args.args[1].annotation = &annotation
	sig.args.defaults = [nothing]
	sig.mutable_vars = ['suffix']
	sig.condition_walrus_names = ['suffix']
	mut registry := new_module_registry()
	register_defaulted_functions({
		'pkg.provider': Module{ body: [Stmt(sig)] }
	}, mut registry)
	assert registry.defaulted_functions.len == 0
}

fn test_optional_scalar_type_excludes_containers_and_references() {
	for typ in ['?string', '?int', '?i64', '?f64', '?bool'] {
		assert is_optional_value_type(typ)
	}
	for typ in ['', '?', 'string', '?Any', '?[]string', '?map[string]int', '?&Thing'] {
		assert !is_optional_value_type(typ)
	}
}

fn test_imported_integral_float_defaults_keep_their_python_kind() {
	for value in [0, 1] {
		mut t := defaults_test_transpiler()
		mut sig := t.registry.defaulted_functions['pkg.provider.greet']
		sig.args.defaults = [Expr(Constant{ value: value, v_annotation: 'float' })]
		t.registry.defaulted_functions['pkg.provider.greet'] = sig
		assert t.visit_call(defaults_test_call()) == 'greet(7, ${value}.0)'
	}
}

fn test_imported_float_defaults_include_negative_zero() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	annotation := Expr(Name{ id: 'float' })
	sig.args.args[1].annotation = &annotation
	zero := Expr(Constant{ value: 0, v_annotation: 'float' })
	sig.args.defaults = [Expr(UnaryOp{ op: USub{}, operand: &zero })]
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.visit_call(defaults_test_call()) == 'greet(7, -0.0)'
	sig.args.defaults = [Expr(Constant{ value: 0, v_annotation: 'int' })]
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.complete_imported_call(defaults_test_call()) == none
}

fn test_local_library_defaults_keep_the_private_function_name() {
	mut t := defaults_test_transpiler()
	t.current_dotted = 'pkg.provider'
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.name = '_greet'
	sig.loc = Location{ lineno: 1, end_lineno: 10 }
	t.registry.defaulted_functions['pkg.provider._greet'] = sig
	_ = t.visit_module(Module{ body: [Stmt(sig)] })
	callee := Expr(Name{ id: '_greet' })
	call := Call{ ...defaults_test_call(), func: &callee, loc: Location{ lineno: 11 } }
	assert t.visit_call(call) == "greet_(7, '!')"
	assert t.complete_imported_call(Call{ ...call, loc: Location{ lineno: 1 } }) == none
}

fn test_local_library_defaults_still_reject_shadowed_names() {
	mut t := defaults_test_transpiler()
	t.current_dotted = 'pkg.provider'
	t.local_idents['greet'] = 'greet'
	assert t.complete_imported_call(defaults_test_call()) == none
}

fn test_imported_keyword_only_defaults_complete_an_empty_call() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args = Arguments{
		kwonlyargs:  [Arg{ arg: 'left' }, Arg{ arg: 'right' }]
		kw_defaults: []?Expr{len: 2}
	}
	sig.args.kw_defaults[0] = Expr(Constant{ value: 5 })
	sig.args.kw_defaults[1] = Expr(Constant{ value: 7 })
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.visit_call(Call{ ...defaults_test_call(), args: []Expr{} }) == 'greet(5, 7)'
	mut registry := new_module_registry()
	register_defaulted_functions({
		'pkg.provider': Module{ body: [Stmt(sig)] }
	}, mut registry)
	assert registry.defaulted_functions.len == 1
	sig.mutable_vars = ['left']
	mut rejected := new_module_registry()
	register_defaulted_functions({
		'pkg.provider': Module{ body: [Stmt(sig)] }
	}, mut rejected)
	assert rejected.defaulted_functions.len == 0
}

fn test_imported_required_keyword_can_precede_a_default() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args = Arguments{
		args:        [Arg{ arg: 'value' }]
		kwonlyargs:  [Arg{ arg: 'required' }, Arg{ arg: 'tail' }]
		kw_defaults: []?Expr{len: 2}
	}
	sig.args.kw_defaults[1] = Expr(Constant{ value: 5 })
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.visit_call(Call{ ...defaults_test_call(), keywords: [Keyword{ arg: 'required', value: Constant{ value: 8 } }] }) == 'greet(7, 8, 5)'
	assert t.complete_imported_call(defaults_test_call()) == none
}

fn test_imported_keyword_only_parameters_do_not_accept_positional_values() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args = Arguments{
		args:        [Arg{ arg: 'value' }]
		kwonlyargs:  [Arg{ arg: 'first' }, Arg{ arg: 'last' }]
		kw_defaults: []?Expr{len: 2}
	}
	sig.args.kw_defaults[0] = Expr(Constant{ value: 2 })
	sig.args.kw_defaults[1] = Expr(Constant{ value: 3 })
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.complete_imported_call(Call{
		...defaults_test_call()
		args: [
			Expr(Constant{ value: 7 }),
			Expr(Constant{ value: 9 }),
		]
	}) == none
}

fn test_imported_keyword_only_defaults_leave_definition_time_expressions_alone() {
	mut t := defaults_test_transpiler()
	mut sig := t.registry.defaulted_functions['pkg.provider.greet']
	sig.args = Arguments{
		args:        [Arg{ arg: 'value' }]
		kwonlyargs:  [Arg{ arg: 'suffix' }]
		kw_defaults: []?Expr{len: 1}
	}
	sig.args.kw_defaults[0] = Expr(Name{ id: 'shared' })
	t.registry.defaulted_functions['pkg.provider.greet'] = sig
	assert t.complete_imported_call(defaults_test_call()) == none
}
