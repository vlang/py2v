module main

const max_generated_line_len = 121

pub struct VTranspiler {
mut:
	wide_members      map[string]bool
	unsupported_sites map[string]string
	tmp_gen           TmpVarGen
	usings            []string
	// Above zero while emitting a match guard or a comprehension whose target is not
	// one identifier (their text is rewritten by plain substring replacement
	// afterwards), a comprehension with a walrus in its filter, or one whose loop
	// variable is named like the helper. F-string specs are not kept inside them.
	comp_depth int
	// Above zero while emitting the body of a `defer` block.
	defer_depth int
	// An uncaught SystemExit must execute pending finally bodies before exiting.
	exit_finally_bodies [][]Stmt
	// Set when an f-string field calls the py2v_format helper.
	uses_py2v_format bool
	// Maps and state tracked during transpilation
	current_class_name     string
	current_classmethod    bool
	emitting_function      bool
	nominal_enums          map[string]bool
	escaped_identifiers    map[string]bool
	extra_mut_vars         map[string]bool
	func_defaults          map[string][]string
	func_param_count       map[string]int
	call_signatures        map[string]FunctionDef
	module_safe_signatures map[string]FunctionDef
	module_scalar_defaults map[string]int
	module_functions       map[string]bool
	default_import_names   map[string]bool
	call_before_def        map[string]bool
	func_return_types      map[string]string
	numeric_scalar_results map[string]bool
	numeric_array_results  map[string]bool
	recursive_int_results  map[string]bool
	// Methods whose receiver must be `mut` in V, keyed ClassName_method.
	mut_receiver_methods map[string]bool
	// Constructor factories mark an emitted fallback parameter here.
	generated_code_has_any_type bool
	uses_any_operators          bool
	any_parameter_names         map[string]bool
	global_vars                 map[string]bool
	has_global_decl             bool
	mut_param_indices           map[string][]int
	generator_signatures        map[string]GeneratorSignature
	func_param_types            map[string][]string // module function -> the V types of its parameters
	var_types                   map[string]string
	// Exact numeric element provenance; []f64 by itself does not prove Python floats.
	sum_list_kinds            map[string]string
	sum_float_results         map[string]bool
	sum_parameter_kinds       map[string][]string
	sum_array_binding         string
	sum_array_results         map[string]bool
	sum_uniform_array_results map[string]bool
	// State for the if-condition lowering, saved separately for each scope.
	condition_walrus_vars    map[string]bool
	condition_walrus_types   map[string]string
	condition_walrus_initial map[string]string
	condition_walrus_order   []string
	// Pending type notes emitted as // comments before the next function/method
	pending_type_notes []string
	// Class metadata
	class_attr_symbols  map[string]map[string]string
	class_field_escapes map[string]map[string]string
	class_base_names    map[string][]string
	class_direct_fields map[string][]string
	class_type_params   map[string][]string // type_params per class name
	known_classes       map[string][]string
	// ref_classes holds the classes of this module that have a field of their own
	// type (a linked-list or tree node). V refuses such a struct by value, and
	// Python shares the object between every name, so an instance is a `&T`
	// wherever its type is written.
	ref_classes             map[string]bool
	module_classes          map[string]bool // classes named Sequence, Iterable or Mapping anywhere in the module
	local_init_constructors map[string]InitConstructor
	init_import_aliases     map[string]string
	init_capture_locals     map[string]bool
	// Module name for emitted code
	module_name string
	source_file string
	// source_words are the current module's; helpers_used lists the run-time helper
	// kinds this module asked for.
	source_words []string
	helpers_used []string
	// helper_requests counts the calls to run-time helpers emitted so far.
	helper_requests int
	// lambda_params counts, by name, the parameters of the lambdas being emitted. Such a
	// name can carry the type of an outer variable it shadows.
	lambda_params map[string]int
	// current_return_count is the arity of the enclosing function's V return
	// tuple, or 0 when it returns a single value.
	current_return_count int
	current_return_type  string
	// Project translation state. `emit_pub` makes top-level symbols visible
	// across V modules; `registry` maps Python module paths to V modules;
	// `current_dotted` is this module's Python dotted path.
	// current_is_package is true when that path names a package rather than a
	// module, which is what a relative import resolves against.
	emit_pub       bool
	registry       ModuleRegistry
	current_dotted string
	// fn_returns_result: the function being emitted returns a V result (`!T`).
	fn_returns_result    bool
	in_entry             bool
	entry_returns_result bool
	result_wrappers      map[string]string
	native_exceptions    map[string][]string
	binds_native_error   bool
	reports_native_error bool
	active_error_guard   int
	// current_stem is this file's stem, used to disambiguate a Python `main`
	// when several files of one V module define one.
	current_stem string
	// current_is_package reports whether current_dotted names a package, i.e.
	// the file being emitted is an `__init__.py`.
	current_is_package bool
	// import_aliases maps a name bound by `from proj.mod import name` to the V
	// module prefix needed to reach it, e.g. `double` -> `util`.
	import_aliases map[string]string
	// imported_modules records local names bound by module imports, so that
	// `name.attr(...)` is not mistaken for a method call on a value.
	imported_modules map[string]bool
	// loop_idents holds the iteration variables currently in scope. V forbids a
	// nested loop from reusing one, so a collision forces a fresh name.
	loop_idents           map[string]bool
	integer_loop_bounds   map[string]NativeIntegerBounds
	integer_update_names  []string
	integer_return_inputs map[string][]int
	integer_return_names  []string
	proven_counter_step   string
	// loop_breaks has one entry per loop whose body is being emitted, innermost
	// last, so a `break` knows whether it leaves a loop that has an `else`.
	loop_breaks []LoopBreak
	// scope_idents holds every V name bound so far in the function being
	// emitted, its parameters included. V rejects a `for` variable that
	// shadows any of them, not only an enclosing iteration variable, so Python's
	// habit of rebinding a parameter inside a loop has to be given a fresh name.
	scope_idents map[string]string
	// param_idents records whether a parameter has an assignable local binding.
	param_idents map[string]bool
	// loop_prelude holds the lines the next loop body starts with: the
	// assignments that keep a rebound local in step with its fresh loop name.
	loop_prelude []string
	// renamed_idents maps a Python name to the V name its current scope bound
	// it to.
	renamed_idents map[string]string
	// import_prefixes records the V module names that name references get
	// qualified with, whether they came from `import pkg` or from
	// `from pkg.mod import name`. A reference such as `pkg.Klass` starts with
	// one of these, which is what tells a qualified constructor apart from a
	// method call on a value that happens to share a class name.
	import_prefixes map[string]bool
	// module_aliases maps a local name from `import a.b as c` to the Python
	// module it refers to.
	module_aliases map[string]string
	// imported_classes maps a class name imported from another project module to
	// its field list, so struct literals and base-class checks resolve without
	// transpiling that module first.
	imported_classes map[string][]string
	// star_imports lists the V modules reached through `from X import *`. Their
	// public names are visible unqualified, so a bare reference has to be
	// qualified with whichever of these modules defines it.
	star_imports []string
	// local_idents maps a Python local name to the V spelling it was declared
	// under, so that references agree with the declaration. V rejects uppercase
	// in variable and parameter names, so the two can differ.
	local_idents map[string]string
	// module_idents does the same for module-level bindings. A module constant
	// such as `USER_CONFIG_PATH` is declared lowercase and has to be read back
	// under that spelling from the constants that build on it, including from
	// inside functions, where the local scope table does not apply.
	module_idents map[string]string
	// The classes defined at the top level of this module, known before any
	// function is rendered. A class is a type in V, never a captured variable.
	module_class_names map[string]bool
	// submodule_aliases maps a local name bound by `from . import mod` to the
	// Python submodule it names, when that submodule shares the current V module.
	submodule_aliases map[string]string
	// unmapped_modules lists Python modules that were imported but have no V
	// mapping. Calls into them cannot be expressed as V, and emitting them
	// verbatim produces `ctypes.CDLL(a, b)` — a field access V cannot parse.
	unmapped_modules map[string]bool
	// unmapped_calls records the call sites that had to be stubbed, reported
	// once at module scope so the gap is visible rather than silent.
	unmapped_calls []string
	// exception_handlers labels the `except` clauses that have no generated
	// code, reported once at module scope.
	exception_handlers []string
	// unresolved_imports lists Python modules with no V counterpart. They are
	// reported at module scope rather than left to fail as undefined
	// identifiers at every use site.
	unresolved_imports []string
	// path_vars tracks variables known to hold pathlib.Path values (represented as strings)
	path_vars map[string]bool
	// regex_vars tracks variables known to hold compiled regex.RE objects
	regex_vars map[string]bool
	// namedtuple_fields maps struct name → ordered field names for namedtuple() calls
	namedtuple_fields map[string][]string
}

// emitted_class_name maps a Python class name to the V type name. V requires
// a type name to begin with a capital letter, so a leading underscore is
// dropped and the next letter is capitalised: `_LazyImport` -> `LazyImport`.
fn emitted_class_name(name string) string {
	if name.len == 1 {
		c := name[0]
		if c >= `A` && c <= `Z` {
			return '${name}_struct'
		}
	}
	if name.starts_with('_') {
		trimmed := name.trim_left('_')
		if trimmed.len == 0 {
			return name
		}
		return trimmed[0].ascii_str().to_upper() + trimmed[1..]
	}
	if name != '' && name[0] >= `a` && name[0] <= `z` {
		return 'Py2v_${name}'
	}
	return name
}

fn (t &VTranspiler) local_class_name(name string) string {
	return t.registry.class_names['${t.current_dotted}.${name}'] or { emitted_class_name(name) }
}

fn expr_class_path(expr Expr) string {
	return match expr {
		Name { expr.class_path }
		Attribute { expr.class_path }
		else { '' }
	}
}

fn (mut t VTranspiler) renamed_class(path string) ?string {
	name := t.registry.class_names[path] or { return none }
	owner := t.registry.lookup(path.all_before_last('.'))
	if owner.v_module == t.module_name { return name }
	t.add_using(owner.v_module)
	return '${owner.v_module}.${name}'
}

fn (mut t VTranspiler) renamed_static_member(node Attribute) ?string {
	path := expr_class_path(*node.value)
	if !t.registry.class_static_members['${path}.${node.attr}'] { return none }
	owner := t.renamed_class(path) or { return none }
	name := '${to_symbol_ident(owner.all_after_last('.'))}_${escape_leading_underscore(node.attr)}'
	return if owner.contains('.') { '${owner.all_before_last('.')}.${name}' } else { name }
}

// new_transpiler creates a new VTranspiler instance
pub fn new_transpiler() VTranspiler {
	return VTranspiler{
		class_attr_symbols:   map[string]map[string]string{}
		class_base_names:     map[string][]string{}
		class_direct_fields:  map[string][]string{}
		class_field_escapes:  map[string]map[string]string{}
		current_class_name:   ''
		escaped_identifiers:  map[string]bool{}
		extra_mut_vars:       map[string]bool{}
		func_defaults:        map[string][]string{}
		func_param_count:     map[string]int{}
		func_return_types:    map[string]string{}
		has_global_decl:      false
		global_vars:          map[string]bool{}
		import_aliases:       map[string]string{}
		imported_modules:     map[string]bool{}
		import_prefixes:      map[string]bool{}
		loop_idents:          map[string]bool{}
		scope_idents:         map[string]string{}
		unmapped_modules:     map[string]bool{}
		unmapped_calls:       []string{}
		exception_handlers:   []string{}
		renamed_idents:       map[string]string{}
		module_aliases:       map[string]string{}
		imported_classes:     map[string][]string{}
		submodule_aliases:    map[string]string{}
		local_idents:         map[string]string{}
		module_idents:        map[string]string{}
		known_classes:        map[string][]string{}
		module_name:          ''
		current_return_count: 0
		mut_param_indices:    map[string][]int{}
		mut_receiver_methods: map[string]bool{}
		namedtuple_fields:    map[string][]string{}
		path_vars:            map[string]bool{}
		regex_vars:           map[string]bool{}
		tmp_gen:              new_tmp_var_gen()
		usings:               []string{}
		var_types:            map[string]string{}
		sum_list_kinds:       map[string]string{}
	}
}

// visit_module emits the top-level V module source for a Module node.
// private_names_shared_with_siblings lists this file's private module-level names that
// another file of the same V module defines too.
fn (t VTranspiler) private_names_shared_with_siblings() map[string]bool {
	mut shared := map[string]bool{}
	if !t.emit_pub || t.current_stem == '' {
		return shared
	}
	prefix := t.module_name + '.'
	for key, _ in t.registry.collisions() {
		if key.starts_with(prefix) {
			name := key[prefix.len..]
			if name.starts_with('_') && !name.starts_with('__') {
				shared[name] = true
			}
		}
	}
	return shared
}

// module_value_name is the V name of a module-level value: its usual spelling, or one
// qualified by the file where a sibling defines the same private name.
fn (t VTranspiler) module_value_name(id string, shared map[string]bool) string {
	if shared[id] {
		return '${t.current_stem}_${escape_local_decl(id)}'
	}
	return escape_local_decl(id)
}

// emitted_fn_name maps a Python function name to the V name it is declared
// under. A `main` in a library keeps its Python name in script mode, but a
// library module is merged with its siblings and must carry one entry point at
// most, so the name is qualified by the file it came from.
pub fn (t VTranspiler) emitted_fn_name(name string) string {
	if t.emit_pub && t.current_stem != '' && name == 'main' {
		return t.current_stem + '_main'
	}
	return t.registry.function_names['${t.current_dotted}.${name}'] or { name }
}

// visit_module renders a whole Python module: constants, imports, structs and
// functions, in the order V requires them.
pub fn (mut t VTranspiler) visit_module(node Module) string {
	t.prepare_init_constructors(node)
	mut bindings := map[string]int{}
	if !t.emit_pub { bindings[':load:'] = 1 }
	mut calls := []BindingCall{}
	t.native_exceptions = map[string][]string{}
	t.binds_native_error = false
	t.reports_native_error = false
	collect_module_info(node, mut bindings, mut calls, mut t.native_exceptions, false)
	t.default_import_names = imported_default_names(node, bindings)
	t.prepare_local_default_names(node)
	mut signatures := map[string]FunctionDef{}
	mut module_defs := map[string][]FunctionDef{}
	t.module_scalar_defaults = map[string]int{}
	for stmt in node.body {
		match stmt {
			FunctionDef {
				module_defs[stmt.name] << stmt
				// In a project this pass cannot see calls from other files.
				if !t.emit_pub && bindings[stmt.name] == 1 && bindings['*'] == 0 && stmt.decorator_list.len == 0 {
					signatures[stmt.name] = stmt
				}
			}
			Assign {
				if stmt.targets.len == 1 && stmt.targets[0] is Name && call_literal_default(stmt.value) {
					name := stmt.targets[0].id
					if name in node.module_consts {
						t.module_scalar_defaults[name] = stmt.loc.lineno
					}
				}
			}
			AnnAssign {
				if stmt.target is Name && stmt.target.id in node.module_consts {
					if value := stmt.value {
						if call_literal_default(*value) {
							t.module_scalar_defaults[stmt.target.id] = stmt.loc.lineno
						}
					}
				}
			}
			else {}
		}
	}
	t.call_signatures = signatures
	t.module_safe_signatures = signatures.clone()
	t.module_functions = map[string]bool{}
	for name in module_defs.keys() { t.module_functions[name] = true }
	t.call_before_def = map[string]bool{}
	mut rejected := false
	for site in calls {
		call := site.call
		// Only calls by name to a top-level function of this file are checked below. A call by name to
		// anything else (a class, a nested function, a lambda, an import) or any other call with
		// keywords is emitted as before, and its error can cancel a bound call's.
		if call.func is Name {
			callee := (call.func as Name).id
			if callee in call_dispatch_names {
				// A dispatched name the file binds itself (a class Path, a def sum) is not the builtin.
				if call.keywords.len > 0 || bindings[callee] > 0 {
					rejected = true
				}
			} else if callee !in module_defs {
				rejected = true
			}
		} else if call.keywords.len > 0 {
			rejected = true
		}
		if call.func !is Name { continue }
		for sig in module_defs[(call.func as Name).id] {
			if !site.in_function && call.loc.lineno <= sig.loc.end_lineno {
				t.call_before_def[call.loc.str()] = true
			}
			if call.keywords.len > 0 || (call.args.len < sig.args.posonlyargs.len + sig.args.args.len && sig.args.defaults.len > 0)
				|| sig.args.kw_defaults.any(it != none) {
				if _ := t.bind_module_call(call, false) {} else { rejected = true }
			}
		}
	}
	// A rejected call can cancel another wrong binding; preserve the entire module.
	if rejected { t.call_signatures.clear() }
	// Reset per-module state so repeated transpilation with the same instance
	// does not leak global-declaration flags.
	t.has_global_decl = false
	t.ref_classes = map[string]bool{}
	t.prescan_ref_classes(node.body)
	t.source_words = node.source_words
	t.helpers_used = []
	t.unsupported_sites.clear()
	t.entry_returns_result = false
	t.result_wrappers = map[string]string{}
	for name in node.source_words {
		t.tmp_gen.taken[name] = true
	}

	mut module_name := t.module_name
	if module_name.len == 0 {
		module_name = 'main'
	}

	// Buckets — emitted in order: type_decls, struct_decls, func_decls, main_fn
	mut type_decls := []string{} // `type X = ...`, `const ...`
	mut struct_decls := []string{} // `pub struct ...` (from ClassDef)
	mut func_decls := []string{} // `fn ...` (non-main functions)
	mut main_fn_body := []string{} // body lines for fn main()
	mut main_fn_stmts := []Stmt{} // the statements those lines came from
	mut main_fn_override := '' // full `fn main() {...}` from guard rewrite
	mut comment_lines := []string{} // top-level import comments etc.

	mut nested_fndefs := []string{}
	t.prescan_abc_names(node.body)
	// A `def` nested inside a module-level `if`/`for`/`try` cannot be emitted
	// there: V only allows `fn` declarations at module top level.
	mut hoisted_body := t.hoist_module_fns(node.body, mut nested_fndefs)
	t.plan_float_sum_sources(hoisted_body, bindings, calls)
	t.sum_array_results = map[string]bool{}
	t.sum_uniform_array_results = map[string]bool{}
	t.integer_return_inputs = map[string][]int{}
	find_growth_calls(hoisted_body, false, mut t.integer_return_inputs)
	propagate_growth_calls(hoisted_body, mut t.integer_return_inputs)
	t.numeric_array_results = map[string]bool{}
	t.numeric_scalar_results = map[string]bool{}
	t.recursive_int_results = map[string]bool{}
	if t.module_name in ['', 'main'] {
		for stmt in hoisted_body {
			if stmt is FunctionDef {
				if stmt.name in signatures && recursive_int_result(stmt) {
					t.recursive_int_results[stmt.name] = true
					continue
				}
				match numeric_choice_result(stmt) {
					'Py2vNumber' { t.numeric_scalar_results[stmt.name] = true }
					'[]Py2vNumber' { t.numeric_array_results[stmt.name] = true }
					else {}
				}
			}
		}
	}

	// A caller may be emitted before its callee. Predeclare native mutable
	// parameters so those earlier calls include V's required `mut` keyword.
	for stmt in hoisted_body {
		if stmt is FunctionDef && stmt.name in signatures && !stmt.is_class_method {
			mut indices := []int{}
			mut args := stmt.args.posonlyargs.clone()
			args << stmt.args.args
			mut index := 0
			for arg in args {
				if arg.arg == 'self' || (arg.arg == 'cls' && stmt.decorator_kind == 'classmethod') {
					continue
				}
				if arg.arg in stmt.mutable_vars && arg.is_mutable
					&& !for_rebinds_parameter(stmt.body, arg.arg) {
					mut typ := ''
					if ann := arg.annotation {
						typ = t.typename_from_annotation(*ann)
					} else if arg.v_annotation != '' {
						typ = t.map_type(arg.v_annotation)
					}
					if typ.starts_with('[]') || typ.starts_with('map[') {
						indices << index
					}
				}
				index++
			}
			if indices.len > 0 {
				t.mut_param_indices[stmt.name] = indices
			}
		}
	}

	// Record the V spelling of every module-level binding before anything is
	// rendered, so that a constant's value refers to it by that same spelling.
	// A private module-level value (`_logger`) that a sibling file of the same V module
	// also defines is declared under this file's name: Python keeps them apart by file,
	// V merges a directory into one module.
	shared := t.private_names_shared_with_siblings()
	for stmt in hoisted_body {
		if stmt is Assign {
			assign := stmt as Assign
			if assign.targets.len == 1 && assign.targets[0] is Name {
				id := (assign.targets[0] as Name).id
				t.module_idents[id] = t.module_value_name(id, shared)
			}
		}
		if stmt is AnnAssign {
			ann := stmt as AnnAssign
			if ann.target is Name {
				id := (ann.target as Name).id
				t.module_idents[id] = t.module_value_name(id, shared)
			}
		}
		if stmt is ClassDef {
			t.module_class_names[(stmt as ClassDef).name] = true
		}
		if stmt is FunctionDef || stmt is AsyncFunctionDef {
			name := if stmt is FunctionDef { stmt.name } else { (stmt as AsyncFunctionDef).name }
			if renamed := t.registry.function_names['${t.current_dotted}.${name}'] {
				t.module_idents[name] = renamed
			}
		}
	}
	for name, first in node.rebound_functions {
		spelling := t.module_value_name(name, shared)
		t.module_idents[name] = spelling
		t.global_vars[name] = true
		t.has_global_decl = true
		type_decls << '__global ${spelling} = ${t.emitted_fn_name(first)}'
	}

	// A library module has no entry point, and V merges a directory into a
	// single module, so two files that each define `main` would collide. The
	// Python sources are separate scripts, so `visit_function_def` keeps such a
	// function under a name derived from its own file. That also covers the
	// `if __name__ == "__main__"` guard, which the frontend rewrites into a
	// `main` definition, and a `main` nested inside another function, which has
	// to be hoisted to the module top level because V only allows `fn`
	// declarations there.

	if t.emit_pub {
		// Package module initializers are not implemented by the existing emitter.
		t.prepare_condition_walruses([]string{}, []Arg{})
	} else {
		t.prepare_condition_walruses(node.condition_walrus_names, []Arg{})
	}

	mut first_stmt := true
	for stmt in hoisted_body {
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
		t.in_entry = !t.emit_pub && stmt !is FunctionDef && stmt !is AsyncFunctionDef && stmt !is ClassDef
		s := if t.emit_pub && stmt is Assign && stmt.value is ListComp {
			t.visit_assignment(stmt, true)
		} else {
			t.visit_stmt(stmt)
		}
		t.in_entry = false
		if s.len == 0 {
			continue
		}
		match stmt {
			ClassDef {
				// Class emits struct def + methods; split on first fn boundary
				struct_decls << s
			}
			FunctionDef {
				if stmt.name == 'main' && t.emitted_fn_name('main') == 'main' {
					main_fn_override = s
				} else {
					func_decls << s
				}
			}
			AsyncFunctionDef {
				if stmt.name == 'main' && t.emitted_fn_name('main') == 'main' {
					main_fn_override = s
				} else {
					func_decls << s
				}
			}
			else {
				trimmed := s.trim_space()
				if trimmed.starts_with('type ') || trimmed.starts_with('const ')
					|| trimmed.starts_with('enum ') {
					type_decls << if t.emit_pub && trimmed.starts_with('const ') {
						'pub ' + s
					} else {
						s
					}
				} else if trimmed.starts_with('pub struct ') || trimmed.starts_with('struct ') {
					struct_decls << s
				} else if stmt is TypeAlias {
					type_decls << s
				} else if trimmed.starts_with('//') {
					// Import comments and similar go before fn main()
					comment_lines << s
				} else if decl := module_const_decl(stmt, trimmed, node.module_consts) {
					type_decls << if t.emit_pub { 'pub ' + decl } else { decl }
				} else {
					main_fn_body << s
					main_fn_stmts << stmt
				}
			}
		}
	}

	condition_declarations := t.condition_walrus_declarations()
	if condition_declarations != '' {
		main_fn_body.prepend(condition_declarations)
	}

	func_decls << nested_fndefs
	// A wrapper is still necessary when the generated file uses the original
	// function value, or calls it through a path the lexical planner cannot see.
	// Package wrappers are emitted with their declarations for sibling files.
	references := [type_decls, struct_decls, func_decls, main_fn_body, [main_fn_override]]
	for name, wrapper in t.result_wrappers {
		if references.any(it.any(mentions_result_wrapper(it, name))) {
			func_decls << wrapper
		}
	}
	code_sections := [type_decls, struct_decls, func_decls, main_fn_body, [main_fn_override]]

	// Any type alias must be first among type_decls. A package is merged into
	// one V module per subpackage, so the alias belongs to that module and only
	// the first file of it declares it.
	// Code that calls the runtime imports it, whether or not it also names `Any`.
	for part in code_sections {
		if part.any(it.contains('pyrt.')) {
			t.add_using('pyrt')
			break
		}
	}
	// Inference can consider types that never reach the rendered code.
	mut needs_any := t.generated_code_has_any_type
	for part in code_sections {
		if part.any(mentions_word(it, 'Any')) {
			needs_any = true
			break
		}
	}
	// One file can need the type while another uses its operators.
	if t.uses_any_operators && (needs_any || t.registry.any_declared_in[t.module_name])
		&& !t.registry.any_operators_declared_in[t.module_name] {
		t.registry.any_operators_declared_in[t.module_name] = true
		t.add_using('pyrt')
		type_decls.prepend(any_operators)
	}
	if needs_any && !t.registry.any_declared_in[t.module_name] {
		t.registry.any_declared_in[t.module_name] = true
		t.add_using('pyrt')
		type_decls.prepend('type Any = pyrt.Value')
	}

	// A library module has no entry point. Synthesising one would put an
	// `fn main` in every generated file, and V merges a directory into a single
	// module, so the second file would collide with the first. Module-level
	// statements therefore become declarations in their own right, and anything
	// that is genuinely a runtime statement is reported rather than smuggled
	// into a function body.
	mut library_decls := []string{}
	mut main_str := ''
	if t.emit_pub && main_fn_override.len == 0 {
		library_decls << comment_lines
		initializer := t.registry.file_initializers[t.current_dotted]
		mut runtime_lines := []string{}
		for i, line in main_fn_body {
			stmt := main_fn_stmts[i]
			if initializer != '' {
				if stmt is ExprStmt || contains_module_rebinding(stmt, node.rebound_functions) {
					runtime_lines << line
					continue
				}
				if stmt is Assign && stmt.targets.len == 1 && stmt.targets[0] is Name
					&& (stmt.value is Call || stmt.value is Name || runtime_lines.len > 0) {
					if left, right := line.split_once(' := ') {
						id := left.trim_string_left('mut ')
						value := stmt.value
						first := if value is Name { node.rebound_functions[value.id] } else { '' }
						typ := t.infer_expr_type(value)
						if first != '' || (typ != '' && typ != 'Any' && typ != 'void') {
							type_decls << if first != '' {
								'__global ${id} = ${t.emitted_fn_name(first)}'
							} else {
								'__global ${id} ${typ}'
							}
							runtime_lines << '${id} = ${right}'
							continue
						}
					}
				}
			}
			decl := module_scope_decl(stmt, line, t.module_idents)
			library_decls << if decl.starts_with('const ') { 'pub ' + decl } else { decl }
		}
		if initializer != '' {
			func_decls << 'fn ${initializer}() {\n${indent(runtime_lines.join('\n'), 1, '\t')}\n}'
			initializers := t.registry.module_initializers[t.module_name]
			if initializers.len > 0 && initializer == initializers[0] {
				startup_calls := initializers.map('\t${it}()')
				func_decls << 'fn init() {\n${startup_calls.join('\n')}\n}'
			}
		}
	} else {
		// Merge the guard-rewritten body with module-level inits.
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
	}

	if t.entry_returns_result && main_str.contains('fn main() {') {
		entry := t.runtime_helper_name('entry')
		failure := t.report_uncaught_error('err')
		main_str = main_str.replace_once('fn main() {', 'fn ${entry}() ! {') +
			'\n\nfn main() {\n\t${entry}() or { ${failure} }\n}'
	}
	struct_decls << t.native_exception_declarations()

	// Assemble output sections in order
	mut parts := []string{}
	if t.has_global_decl {
		// A translated module uses C-width int. Python arithmetic needs native V int.
		parts << '@[has_globals]'
	}
	parts << 'module ${module_name}'

	if t.usings.len > 0 {
		mut import_lines := []string{}
		for u in t.usings {
			import_lines << 'import ${u}'
		}
		parts << import_lines.join('\n')
	}

	unresolved := t.unresolved_import_comment()
	if unresolved != '' {
		// Reported at module scope. Emitting these inside fn main() would bury
		// a project-wide problem in the body of one function.
		parts << unresolved
	}

	unmapped := t.unmapped_call_comment()
	if unmapped != '' {
		parts << unmapped
	}

	handlers := t.exception_handler_comment()
	if handlers != '' {
		parts << handlers
	}

	if library_decls.len > 0 {
		parts << library_decls.join('\n')
	}

	if type_decls.len > 0 {
		parts << type_decls.join('\n\n')
	}
	if struct_decls.len > 0 {
		parts << struct_decls.join('\n\n')
	}
	if t.uses_py2v_format && !t.registry.py2v_format_declared_in[t.module_name] {
		t.registry.py2v_format_declared_in[t.module_name] = true
		func_decls << py2v_format_helper
	}
	// Keep unsafe module declarations visible behind an explicit compilation refusal.
	if node.list_identity_module_errors.len > 0 {
		for reason in node.list_identity_module_errors {
			message := 'py2v: module-level list refusal: ${reason.replace('\n', ' ')}'
			eprintln(message)
			func_decls << '// ${message}'
		}
		key := '${t.module_name}.list_identity_module_guard'
		if !t.registry.helper_declared[key] {
			t.registry.helper_declared[key] = true
			name := t.runtime_helper_name('list_identity_module_guard')
			refusal := t.runtime_helper_name('unsupported_list_identity_module')
			func_decls << 'const ${name} = ${refusal}()'
		}
	}
	// A run-time helper is declared in the first file of a V module that asks for it.
	for kind in t.helpers_used {
		key := '${t.module_name}.${kind}'
		if !t.registry.helper_declared[key] {
			t.registry.helper_declared[key] = true
			func_decls << t.runtime_helper_declaration(kind)
		}
	}
	if func_decls.len > 0 {
		parts << func_decls.join('\n\n')
	}
	if main_str != '' {
		parts << main_str
	}

	return t.keep_unsupported_checks(parts.join('\n\n')) + '\n'
}

// runtime_helper_name returns the name of the run-time helper `kind` in the current module.
fn (mut t VTranspiler) runtime_helper_name(kind string) string {
	return t.registry.helper_name(t.module_name, kind, t.source_words)
}

// runtime_helper asks for the run-time helper `kind` and returns its name.
fn (mut t VTranspiler) runtime_helper(kind string) string {
	t.helper_requests++
	if kind !in t.helpers_used {
		t.helpers_used << kind
	}
	return t.runtime_helper_name(kind)
}

// integer_site supplies a constant source location to an emitted checked operation.
fn (t &VTranspiler) integer_site(loc Location) string {
	file := if t.source_file != '' { t.source_file } else { '<input>' }
	return v_string_literal('${file}:${loc.lineno}')
}

// require_integer_helper registers a native implementation and its dependencies.
fn (mut t VTranspiler) require_integer_helper(kind string) string {
	if kind !in ['floor_div', 'mod', 'divmod', 'right_shift'] {
		t.runtime_helper('integer_overflow')
	}
	if kind in ['power', 'sum'] {
		t.runtime_helper(if kind == 'power' { 'integer_mul' } else { 'integer_add' })
	}
	if kind == 'inferred_sum' {
		t.require_integer_helper('sum')
		t.add_using('math')
	}
	if kind == 'inferred_power' {
		t.require_integer_helper('power')
		t.add_using('math')
	}
	if kind == 'divmod' {
		t.runtime_helper('integer_floor_div')
		t.runtime_helper('integer_mod')
	}
	return t.runtime_helper('integer_${kind}')
}

fn integer_operation_suffix(kind string) string {
	return match kind {
		'add' { ", 'addition'" }
		'mul' { ", 'multiplication'" }
		else { '' }
	}
}

// checked_integer emits a call whose result fits in the native representation.
fn (mut t VTranspiler) checked_integer(kind string, args []string, loc Location) string {
	helper := t.require_integer_helper(kind)
	return '${helper}(${args.join(', ')}, ${t.integer_site(loc)}${integer_operation_suffix(kind)})'
}

// generic_integer chooses the native integer path after V resolves the operand types.
// The callback gives V the original operator's result type and handles overloads.
fn (mut t VTranspiler) generic_integer(kind string, op string, a string, b string, loc Location) string {
	t.require_integer_helper(kind)
	t.runtime_helper('integer_overflow')
	t.add_using('math')
	helper := t.runtime_helper('integer_generic_${kind}')
	lhs := t.new_tmp('operand')
	rhs := t.new_tmp('operand')
	return '${helper}(${a}, ${b}, ${t.integer_site(loc)}, |${lhs}, ${rhs}| ${lhs} ${op} ${rhs})'
}

fn (mut t VTranspiler) generic_integer_declaration(kind string, name string) string {
	checked := t.runtime_helper_name('integer_${kind}')
	failure := t.runtime_helper_name('integer_overflow')
	return 'fn ${name}[A, B, R](a A, b B, site string, fallback fn (A, B) R) R {\n' +
		'\t\$if A is \$int && B is \$int && R is \$int {\n' +
		'\t\t\$if A is u64 || B is u64 || R is u64 {\n' +
		"\t\t\t\$compile_error('py2v_unsupported_wide_integer: generic arithmetic needs a signed native result')\n" +
		'\t\t} \$else {\n' +
		'\t\t\tvalue := ${checked}(int(a), int(b), site${integer_operation_suffix(kind)})\n' +
		'\t\t\tif value < int(math.minof[R]()) || value > int(math.maxof[R]()) {\n' +
		"\t\t\t\t${failure}(site, 'integer narrowing')\n\t\t\t}\n" +
		'\t\t\treturn R(value)\n\t\t}\n\t} \$else {\n' +
		'\t\treturn fallback(a, b)\n\t}\n}'
}

// integer_helper_declaration emits the checked or exact native integer operations.
fn (mut t VTranspiler) integer_helper_declaration(kind string, name string) string {
	if kind.starts_with('integer_generic_') {
		return t.generic_integer_declaration(kind.trim_string_left('integer_generic_'), name)
	}
	failure := t.runtime_helper_name('integer_overflow')
	match kind {
		'numeric_choice' {
			float_text := t.runtime_helper_name('float_text')
			return 'type Py2vNumber = f64 | int\n\n' +
				'fn (value Py2vNumber) str() string {\n' +
				'\treturn match value {\n\t\tf64 { ${float_text}(value) }\n\t\tint { value.str() }\n\t}\n}'
		}
		'numeric_subtract' {
			return 'fn ${name}(a Py2vNumber, b Py2vNumber) Py2vNumber {\n' +
				'\tif a is int && b is int { return Py2vNumber(a - b) }\n' +
				'\treturn Py2vNumber(a.as_float() - b.as_float())\n}'
		}
		'numeric_add', 'numeric_multiply' {
			op := if kind == 'numeric_add' { '+' } else { '*' }
			product := t.runtime_helper_name('integer_mul')
			integer := if kind == 'numeric_add' {
				'a + b'
			} else {
				"${product}(a, b, site, 'multiplication')"
			}
			location := if kind == 'numeric_add' { '' } else { ', site string' }
			return 'fn ${name}(a Py2vNumber, b Py2vNumber${location}) Py2vNumber {\n' +
				'\tif a is int && b is int { return Py2vNumber(${integer}) }\n' +
				'\treturn Py2vNumber(a.as_float() ${op} b.as_float())\n}'
		}
		'numeric_round_sig' {
			return 'fn ${name}(value Py2vNumber, digits int) Py2vNumber {\n' +
				'\tif value is int { return value }\n' +
				'\treturn Py2vNumber(math.round_sig(value as f64, digits))\n}'
		}
		'numeric_type_name' {
			return 'fn ${name}(value Py2vNumber) string {\n' +
				"\treturn match value {\n\t\tf64 { 'float' }\n\t\tint { 'int' }\n\t}\n}"
		}
		'numeric_box' {
			return 'fn ${name}(value Py2vNumber) pyrt.Value {\n' +
				'\treturn match value {\n\t\tf64 { pyrt.box(value) }\n\t\tint { pyrt.box(value) }\n\t}\n}'
		}
		'numeric_as_float' {
			return 'fn (value Py2vNumber) as_float() f64 {\n' +
				'\treturn match value {\n\t\tf64 { value }\n\t\tint { f64(value) }\n\t}\n}'
		}
		'numeric_abs' {
			return 'fn ${name}(value Py2vNumber) Py2vNumber {\n' +
				'\treturn match value {\n\t\tf64 { Py2vNumber(math.abs(value)) }\n' +
				'\t\tint { Py2vNumber(math.abs(value)) }\n\t}\n}'
		}
		'numeric_compare_float' {
			return 'fn ${name}(value Py2vNumber, other f64) int {\n' + r"
	if math.is_nan(other) { return 2 }
	if value is f64 {
		if math.is_nan(value) { return 2 }
		return int(value > other) - int(value < other)
	}
	if other >= 9223372036854775808.0 { return -1 }
	if other < -9223372036854775808.0 { return 1 }
	whole := int(other)
	signed := value as int
	if signed != whole { return int(signed > whole) - int(signed < whole) }
	return int(f64(whole) > other) - int(f64(whole) < other)
}"
		}
		'numeric_compare_from_float' {
			compare := t.runtime_helper_name('numeric_compare_float')
			return 'fn ${name}(left f64, right Py2vNumber) int {\n\treturn ${compare}(right, left)\n}'
		}
		'numeric_compare_int' {
			compare := t.runtime_helper_name('numeric_compare_float')
			return 'fn ${name}(value Py2vNumber, other int) int {\n' +
				'\tif value is int { return int(value > other) - int(value < other) }\n' +
				'\tresult := ${compare}(Py2vNumber(other), value as f64)\n' +
				'\treturn if result == 2 { 2 } else { -result }\n}'
		}
		'integer_overflow' {
			return '@[noreturn]\nfn ${name}(site string, operation string) {' + r"
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}"
		}
		'integer_add', 'integer_mul' {
			op, check := if kind == 'integer_add' {
				'+', '(b > 0 && a > max - b) || (b < 0 && a < min - b)'
			} else {
				'*', '(a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b)))'
			}
			return '@[inline]\nfn ${name}(a int, b int, site string, operation string) int {\n' +
				'\tmax := int(9223372036854775807)\n\tmin := -max - 1\n' +
				'\tif ${check} { ${failure}(site, operation) }\n\treturn a ${op} b\n}'
		}
		'integer_floor_div', 'integer_mod' {
			head := if kind == 'integer_floor_div' {
				"\tif b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }\n"
			} else {
				"\tif b == 0 { panic('ZeroDivisionError: integer modulo by zero') }\n" +
					'\tif b == -1 { return 0 }\n'
			}
			result := if kind == 'integer_floor_div' {
				'a / b - int(adjust)'
			} else {
				'if adjust { r + b } else { r }'
			}
			return '@[inline]\nfn ${name}(a int, b int, _ string) int {\n' + head +
				'\tr := a % b\n\tadjust := r != 0 && (r < 0) != (b < 0)\n\treturn ${result}\n}'
		}
		'integer_divmod' {
			quot := t.runtime_helper_name('integer_floor_div')
			rem := t.runtime_helper_name('integer_mod')
			return 'fn ${name}(a int, b int, site string) []int {\n' +
				'\treturn [${quot}(a, b, site), ${rem}(a, b, site)]\n}'
		}
		'integer_left_shift' {
			return '@[inline]\nfn ${name}(a int, b int, site string) int {\n' + r"
	if b < 0 { panic('ValueError: negative shift count') }
	if a == 0 { return 0 }
	max := int(9223372036854775807)
	min := -max - 1
	if b == 63 && a == -1 { return min }
	if b >= 63 || a > (max >> b) || a < (min >> b) {
		" + failure + r"(site, 'left shift')
	}
	return a * (int(1) << b)
}"
		}
		'integer_right_shift' {
			return '@[inline]\nfn ${name}(a int, b int, _ string) int {\n' + r"
	if b < 0 { panic('ValueError: negative shift count') }
	if b >= 63 { return if a < 0 { -1 } else { 0 } }
	return a >> b
}"
		}
		'integer_power' {
			multiply := t.runtime_helper_name('integer_mul')
			return 'fn ${name}(a int, b int, site string) int {\n' + r"
	if b < 0 { panic('py2v_unsupported_integer_power: a negative exponent needs a float result') }
	mut base, mut exponent := a, b
	mut result := 1
	for exponent != 0 {
		if exponent & 1 != 0 {
			result = " + multiply + r"(result, base, site, 'power')
		}
		exponent >>= 1
		if exponent != 0 {
			base = " + multiply + r"(base, base, site, 'power')
		}
	}
	return result
}"
		}
		'integer_inferred_power' {
			power := t.runtime_helper_name('integer_power')
			return 'fn ${name}[T](base T, exponent int, site string) T {\n' +
				'\t\$if T is \$float {\n\t\treturn T(math.pow(f64(base), f64(exponent)))\n' +
				'\t} \$else \$if T is \$int && T !is u64 {\n' +
				'\t\tvalue := ${power}(int(base), exponent, site)\n' +
				'\t\tif value < int(math.minof[T]()) || value > int(math.maxof[T]()) {\n' +
				"\t\t\t${failure}(site, 'power')\n\t\t}\n\t\treturn T(value)\n" +
				"\t} \$else { \$compile_error('py2v_unsupported_integer_power: expected a native number') }\n}"
		}
		'integer_sum' {
			add := t.runtime_helper_name('integer_add')
			return 'fn ${name}[T](items []T, start int, site string) int {\n' +
				'\t\$if (T is \$int && T !is u64) || T is bool {\n' +
				"\t\tmut total := start\n\t\tfor item in items { total = ${add}(total, int(item), site, 'sum') }\n\t\treturn total\n" +
				"\t} \$else { \$compile_error('py2v_unsupported_integer_sum: expected native integer elements') }\n}"
		}
		'integer_inferred_sum' {
			sum := t.runtime_helper_name('integer_sum')
			return 'fn ${name}[T](items []T, start int, site string) T {\n' +
				'\t\$if T is u64 {\n' +
				"\t\t\$compile_error('py2v_unsupported_wide_integer: sum may exceed u64')\n" +
				'\t} \$else \$if T is \$int {\n' +
				'\t\tvalue := ${sum}(items, start, site)\n' +
				'\t\tif value < int(math.minof[T]()) || value > int(math.maxof[T]()) {\n' +
				"\t\t\t${failure}(site, 'integer narrowing')\n\t\t}\n" +
				'\t\treturn T(value)\n\t} \$else \$if T is \$float {\n' +
				"\t\t\$compile_error('py2v_unsupported_unproven_float_sum: Python element types are not proven')\n" +
				"\t} \$else { \$compile_error('py2v_unsupported_integer_sum: expected native integer elements') }\n}"
		}
		'integer_factorial' {
			return '@[inline]\nfn ${name}(value int, site string) int {\n' +
				"\tif value < 0 { panic('ValueError: factorial() not defined for negative values') }\n" +
				"\tif value > 20 { ${failure}(site, 'factorial') }\n\treturn int(math.factoriali(value))\n}"
		}
		'integer_isqrt' {
			return 'fn ${name}(value int) int {\n' + r"
	if value < 0 { panic('ValueError: isqrt() argument must be nonnegative') }
	mut remainder := u64(value)
	mut root := u64(0)
	mut bit := u64(1) << 62
	for bit > remainder { bit >>= 2 }
	for bit != 0 {
		trial := root + bit
		root >>= 1
		if remainder >= trial {
			remainder -= trial
			root += bit
		}
		bit >>= 2
	}
	return int(root)
}"
		}
		'integer_word_product' {
			bits := t.runtime_helper_name('math_bits')
			return '@[inline]\nfn ${name}(a u64, b u64, modulus u64) u64 {\n' +
				'\thi, lo := ${bits}.mul_64(a, b)\n\treturn ${bits}.rem_64(hi, lo, modulus)\n}'
		}
		else { panic('py2v has no integer helper ${kind}') }
	}
}

// runtime_helper_declaration returns the V source of the run-time helper `kind`.
fn (mut t VTranspiler) runtime_helper_declaration(kind string) string {
	name := t.runtime_helper_name(kind)
	if kind.starts_with('integer_') || kind.starts_with('numeric_') {
		return t.integer_helper_declaration(kind, name)
	}
	return match kind {
		'bool_text' {
			"fn ${name}(value bool) string {\n\treturn if value { 'True' } else { 'False' }\n}"
		}
		'int_tuple_text' {
			'fn ${name}[T](values T) string {\n' + r"
	mut items := []string{cap: values.len}
	for value in values {
		items << value.str()
	}
	trailing := if values.len == 1 { ',' } else { '' }
	return '(' + items.join(', ') + trailing + ')'
}"
		}
		'string_index' {
			'fn ${name}(value string, index i64, index_error ?IError) !string {\n' + r"
	chars := value.runes()
	offset := if index < 0 { i64(chars.len) + index } else { index }
	if offset < 0 || offset >= i64(chars.len) {
		return index_error or { error('IndexError: string index out of range') }
	}
	return chars[int(offset)].str()
}"
		}
		'string_center' {
			'fn ${name}(value string, width int, fill string) string {\n' + r"
	if fill.runes().len != 1 {
		panic('TypeError: The fill character must be exactly one character long')
	}
	length := value.runes().len
	if width <= length {
		return value
	}
	padding := width - length
	left := padding / 2 + (padding & width & 1)
	return fill.repeat(left) + value + fill.repeat(padding - left)
}"
		}
		'split_whitespace' {
			'fn ${name}(value string) []string {\n' + r"
	return value.split_any(' \t\n\r\u000b\u000c\u001c\u001d\u001e\u001f\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000').filter(it != '')
}"
		}
		'text_is_none' {
			'fn ${name}(value string) bool {\n\t_ = value\n\treturn false\n}'
		}
		'slice_step' {
			'fn ${name}[T](values []T, lower ?int, upper ?int, step int) []T {\n' + r"
	if step == 0 {
		panic('ValueError: slice step cannot be zero')
	}
	n := values.len
	min_index := if step < 0 { -1 } else { 0 }
	max_index := if step < 0 { n - 1 } else { n }
	mut start := if step < 0 { max_index } else { min_index }
	mut stop := if step < 0 { min_index } else { max_index }
	if bound := lower {
		offset := if bound < 0 { bound + n } else { bound }
		start = if offset < min_index { min_index } else if offset > max_index { max_index } else { offset }
	}
	if bound := upper {
		offset := if bound < 0 { bound + n } else { bound }
		stop = if offset < min_index { min_index } else if offset > max_index { max_index } else { offset }
	}
	mut result := []T{}
	for index := start; if step < 0 { index > stop } else { index < stop }; index += step {
		result << values[index]
		if (step < 0 && step <= stop - index) || (step > 0 && step >= stop - index) {
			break
		}
	}
	return result
}"
		}
		'range_next' {
			'fn ${name}(current int, stop int, step int) int {\n' + r"
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
}"
		}
		'range_bound' {
			'@[inline]\nfn ${name}[T](value T) int {\n' + r"
	$if T is $int || T is bool {
		return int(value)
	} $else $if T is $sumtype {
		$for variant in T.variants {
			$if variant is $int || variant is bool {
				if value is variant {
					return int(value)
				}
			}
		}
		panic('TypeError: range needs integer bounds')
	} $else {
		$compile_error('py2v_unsupported_range_bound: range needs integer bounds')
	}
}"
		}
		'range_array' {
			'fn ${name}(start int, stop int, step int) []int {\n' + r"
	if step == 0 {
		panic('ValueError: range() arg 3 must not be zero')
	}
	mut values := []int{}
	for current := start; if step > 0 { current < stop } else { current > stop }; current += step {
		values << current
		if step > 0 {
			if u64(step) >= u64(stop) - u64(current) { break }
		} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
			break
		}
	}
	return values
}"
		}
		'range_unpack' {
			convert := t.runtime_helper_name('range_bound')
			build := t.runtime_helper_name('range_array')
			'fn ${name}[T](values T) []int {\n' + r"
	$if T is $array || T is $array_fixed {
		if values.len !in [1, 2, 3] {
			panic('TypeError: range expected 1 to 3 arguments')
		}
		mut args := [3]int{}
" + '		for i, value in values { args[i] = ${convert}(value) }\n' +
				'		return match values.len {\n' +
				'			1 { ${build}(0, args[0], 1) }\n' +
				'			2 { ${build}(args[0], args[1], 1) }\n' +
				'			else { ${build}(args[0], args[1], args[2]) }\n\t\t}\n' + r"
	} $else {
		$compile_error('py2v_unsupported_range_unpack: range needs a native array')
	}
}"
		}
		'modular_pow' {
			word_product := t.runtime_helper_name('integer_word_product')
			'fn ${name}(base int, exponent int, modulus int) !int {\n' + r"
	if modulus == 0 {
		return error('pow() 3rd argument cannot be 0')
	}
	if modulus == 1 || modulus == -1 {
		return 0
	}
	m := if modulus < 0 { u64(-(modulus + 1)) + 1 } else { u64(modulus) }
	remainder := base % modulus
	mut x := if remainder < 0 { m - u64(-remainder) } else { u64(remainder) }
	if exponent < 0 {
		// Euclid's coefficients can be kept reduced modulo m throughout.
		mut old_r, mut r := m, x
		mut old_coefficient, mut coefficient := u64(0), u64(1)
		for r != 0 {
			product := " + word_product + r"(old_r / r, coefficient, m)
			old_r, r = r, old_r % r
			old_coefficient, coefficient = coefficient, if old_coefficient >= product {
				old_coefficient - product
			} else {
				m - (product - old_coefficient)
			}
		}
		if old_r != 1 {
			return error('base is not invertible for the given modulus')
		}
		x = old_coefficient
	}
	mut degree := if exponent < 0 { u64(-(exponent + 1)) + 1 } else { u64(exponent) }
	mut result := u64(1)
	for degree != 0 {
		if degree & 1 != 0 {
			result = " + word_product + r"(result, x, m)
		}
		degree >>= 1
		if degree != 0 {
			x = " + word_product + r"(x, x, m)
		}
	}
	return if modulus < 0 && result != 0 { -int(m - result) } else { int(result) }
}"
		}
		'int_base_error_text' {
			parse := t.runtime_helper_name('int_base')
			return 'fn ${name}(value string, base int, site string) !int {\n' +
				'\treturn ${parse}(value, base, site) or {\n' +
				"\t\tif err.msg() != 'invalid literal for int()' { return err }\n" + r"
		return error('invalid literal for int() with base ${base}: ' + pyrt.repr(pyrt.box(value)))
	}
}"
		}
		'int_base' {
			failure := t.runtime_helper_name('integer_overflow')
			'fn ${name}(value string, requested_base int, site string) !int {\n' + r"
	if requested_base != 0 && (requested_base < 2 || requested_base > 36) {
		return error('int() base must be >= 2 and <= 36, or 0')
	}
	mut normalized := []u8{cap: value.len}
	for ch in value.runes() {
		if ch < 128 {
			normalized << u8(ch)
		} else if ch in [0x85, 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000] || (ch >= 0x2000 && ch <= 0x200a) {
			normalized << ` `
		} else {
			// Unicode decimal digit groups start at zero and contain ten runes.
			mut digit := u8(`?`)
			for zero in [0x660, 0x6f0, 0x7c0, 0x966, 0x9e6, 0xa66, 0xae6, 0xb66, 0xbe6, 0xc66,
				0xce6, 0xd66, 0xde6, 0xe50, 0xed0, 0xf20, 0x1040, 0x1090, 0x17e0, 0x1810, 0x1946,
				0x19d0, 0x1a80, 0x1a90, 0x1b50, 0x1bb0, 0x1c40, 0x1c50, 0xa620, 0xa8d0, 0xa900,
				0xa9d0, 0xa9f0, 0xaa50, 0xabf0, 0xff10, 0x104a0, 0x10d30, 0x10d40, 0x11066,
				0x110f0, 0x11136, 0x111d0, 0x112f0, 0x11450, 0x114d0, 0x11650, 0x116c0, 0x116d0,
				0x116da, 0x11730, 0x118e0, 0x11950, 0x11bf0, 0x11c50, 0x11d50, 0x11da0, 0x11de0,
				0x11f50, 0x16130, 0x16a60, 0x16ac0, 0x16b50, 0x16d70, 0x1ccf0, 0x1d7ce, 0x1d7d8,
				0x1d7e2, 0x1d7ec, 0x1d7f6, 0x1e140, 0x1e2f0, 0x1e4f0, 0x1e5f1, 0x1e950, 0x1fbf0]! {
				if int(ch) >= zero && int(ch) <= zero + 9 {
					digit = u8(int(ch) - zero) + `0`
					break
				}
			}
			normalized << digit
		}
	}
	text := normalized.bytestr().trim(' \t\n\r\u000b\u000c')
	if text == '' {
		return error('invalid literal for int()')
	}
	negative := text[0] == `-`
	mut start := if negative || text[0] == `+` { 1 } else { 0 }
	mut base := if requested_base == 0 { 10 } else { requested_base }
	mut zero_only := requested_base == 0 && start < text.len && text[start] == `0`
	if start < text.len - 1 && text[start] == `0` {
		prefix_base := match text[start + 1] | 32 {
			`b` { 2 }
			`o` { 8 }
			`x` { 16 }
			else { 0 }
		}
		if prefix_base != 0 && (requested_base == 0 || requested_base == prefix_base) {
			base = prefix_base
			zero_only = false
			start += 2
			if start < text.len && text[start] == `_` {
				start++
			}
		}
	}
	limit := (u64(1) << 63) - u64(!negative)
	mut magnitude := u64(0)
	mut overflow := false
	mut need_digit := true
	radix := u64(base)
	for i in start .. text.len {
		ch := text[i]
		if ch == `_` && !need_digit {
			need_digit = true
			continue
		}
		digit := match ch {
			`0`...`9` { int(ch - `0`) }
			`a`...`z` { int(ch - `a`) + 10 }
			`A`...`Z` { int(ch - `A`) + 10 }
			else { base }
		}
		if digit >= base || (zero_only && digit != 0) {
			return error('invalid literal for int()')
		}
		need_digit = false
		if !overflow {
			overflow = magnitude > (limit - u64(digit)) / radix
			if !overflow {
				magnitude = magnitude * radix + u64(digit)
			}
		}
	}
	if need_digit {
		return error('invalid literal for int()')
	}
	if overflow {
		" + failure + r"(site, 'integer parsing')
	}
	if magnitude == 0 {
		return 0
	}
	return if negative { -int(magnitude - 1) - 1 } else { int(magnitude) }
}"
		}
		'format_radix' {
			'fn ${name}[T](value T, fill string, align string, sign string, zero bool, width int, group string, _ int, typ string) string {\n' + r"
	kind := typ[typ.len - 1]
	base := match kind {
		`b` { 2 }
		`o` { 8 }
		else { 16 }
	}
	mut negative := false
	mut magnitude := u64(0)
	$if T is u64 {
		magnitude = value
	} $else {
		x := i64(value)
		negative = x < 0
		magnitude = if negative { u64(-(x + 1)) + 1 } else { u64(x) }
	}
	mut prefix := if negative { '-' } else if sign == '-' { '' } else { sign }
	if typ.len == 2 {
		prefix += '0' + kind.ascii_str()
	}
	mut digits := strconv.format_uint(magnitude, base)
	if kind == `X` {
		digits = digits.to_upper()
	}
	a := if align != '' { align } else if zero { '=' } else { '>' }
	f := if fill != '' { fill } else if zero { '0' } else { ' ' }
	if group == '_' {
		if a == '=' && f == '0' {
			mut length := digits.len
			for prefix.len + length + (length - 1) / 4 < width { length++ }
			digits = '0'.repeat(length - digits.len) + digits
		}
		mut parts := []string{}
		mut begin := (digits.len - 1) % 4 + 1
		parts << digits[..begin]
		for begin < digits.len {
			parts << digits[begin..begin + 4]
			begin += 4
		}
		digits = parts.join('_')
	}
	pad := width - prefix.len - digits.len
	if pad <= 0 {
		return prefix + digits
	}
	return match a {
		'<' { prefix + digits + f.repeat(pad) }
		'^' { f.repeat(pad / 2) + prefix + digits + f.repeat(pad - pad / 2) }
		'=' { prefix + f.repeat(pad) + digits }
		else { f.repeat(pad) + prefix + digits }
	}
}"
		}
		'bytes_text' {
			'fn ${name}(value []u8) string {\n' + r"
	quote := if u8(39) in value && u8(34) !in value { u8(34) } else { u8(39) }
	mut text := strings.new_builder(value.len + 3)
	text.write_u8(98)
	text.write_u8(quote)
	for byte_value in value {
		if byte_value == quote || byte_value == 92 {
			text.write_u8(92)
			text.write_u8(byte_value)
			continue
		}
		match byte_value {
			9 { text.write_string('\\t') }
			10 { text.write_string('\\n') }
			13 { text.write_string('\\r') }
			32...126 { text.write_u8(byte_value) }
			else { text.write_string('\\x' + '${byte_value:02x}') }
		}
	}
	text.write_u8(quote)
	return text.str()
}"
		}
		'float_text' {
			'fn ${name}[T](value T) string {\n' + r"
	$if T is $float {
		scientific := strconv.f64_to_str(f64(value), 16)
		marker := scientific.index('e') or { return scientific.trim_left('+') }
		exponent := scientific[marker + 1..].int()
		if exponent < -4 || exponent >= 16 {
			return scientific
		}
		sign := if scientific.starts_with('-') { '-' } else { '' }
		digits := scientific[sign.len..marker].replace('.', '')
		point := exponent + 1
		if point <= 0 {
			return sign + '0.' + '0'.repeat(-point) + digits
		}
		if point >= digits.len {
			return sign + digits + '0'.repeat(point - digits.len) + '.0'
		}
		return sign + digits[..point] + '.' + digits[point..]
	} $else {
		return value.str()
	}
}"
		}
		'native_map_pop' {
			'fn ${name}[K, T](mut items map[K]T, key K) T {\n' +
				'\tvalue := items[key]\n\titems.delete(key)\n\treturn value\n}'
		}
		'isinstance_empty' {
			'fn ${name}[T](value T) bool {\n\t_ = value\n\treturn false\n}'
		}
		'assign_expr' {
			'fn ${name}[T](target &T, value T) T {\n' +
				'\tunsafe { *target = value }\n\treturn value\n}'
		}
		'divmod_float', 'divmod_value' {
			typ := if kind == 'divmod_float' {
				'f64'
			} else {
				'pyrt.Value'
			}
			values := if kind == 'divmod_float' {
				'pyrt.to_float(q), pyrt.to_float(r)'
			} else {
				'q, r'
			}
			'fn ${name}[A, B](a A, b B) []${typ} {\n' +
				'\tleft := pyrt.box(a)\n\tright := pyrt.box(b)\n' +
				'\tq := pyrt.floordiv(left, right) or { panic(err) }\n' +
				'\tr := pyrt.mod(left, right) or { panic(err) }\n\treturn [${values}]\n}'
		}
		'append_method' {
			'fn ${name}[T](mut items []T) fn (T) {\n' +
				'\treturn fn [mut items] [T](value T) { items << value }\n}'
		}
		'unsupported_list_identity' {
			'@[noreturn]\nfn ${name}() {\n' +
				"\tpanic('py2v_unsupported_list_identity: list aliases cannot be preserved')\n}"
		}
		'generic_mod' {
			mod := t.runtime_helper_name('integer_mod')
			'fn ${name}[T](a T, b T, site string) T {\n' +
				'\t\$if T is \$float {\n' +
				"\t\tif b == 0 { panic('float modulo by zero') }\n" +
				'\t\tmut r := math.fmod(f64(a), f64(b))\n' +
				'\t\tif r != 0 {\n' +
				'\t\t\tif (r < 0) != (b < 0) { r += f64(b) }\n' +
				'\t\t} else { r = math.copysign(0.0, f64(b)) }\n' +
				'\t\treturn T(r)\n' +
				'\t} \$else \$if T is u64 {\n' +
				'\t\treturn a % b\n' +
				'\t} \$else \$if T is \$int {\n' +
				'\t\treturn T(${mod}(int(a), int(b), site))\n' +
				'\t} \$else { return a % b }\n}'
		}
		'float_mod' {
			'fn ${name}(a f64, b f64) f64 {\n' +
				"\tif b == 0 { panic('float modulo by zero') }\n" +
				'\tmut r := math.fmod(a, b)\n' +
				'\tif r != 0 {\n' +
				'\t\tif (r < 0) != (b < 0) { r += b }\n' +
				'\t} else { r = math.copysign(0.0, b) }\n' +
				'\treturn r\n}'
		}
		'sum_float_suffix' {
			'fn ${name}(items []f64, start f64) f64 {\n' +
				'\tmut total := start\n\tfor item in items { total += item }\n\treturn total\n}'
		}
		'shift_left_u64', 'shift_right_u64' {
			op := if kind == 'shift_left_u64' { '<<' } else { '>>' }
			'fn ${name}[T](value u64, count T) u64 {\n' +
				"\tif count < 0 { panic('ValueError: negative shift count') }\n" +
				'\tif count >= 64 { return 0 }\n' +
				'\treturn value ${op} int(count)\n}'
		}
		'cmp_u64_int', 'cmp_int_u64' {
			args := if kind == 'cmp_u64_int' { 'a u64, b i64' } else { 'b i64, a u64' }
			sign := if kind == 'cmp_u64_int' { 1 } else { -1 }
			'fn ${name}(${args}) int {\n' +
				'\tif b < 0 || a > u64(b) { return ${sign} }\n' +
				'\tif a < u64(b) { return ${-sign} }\n' +
				'\treturn 0\n}'
		}
		'ascii_swapcase' {
			'fn ${name}(value string) string {\n' +
				'\tmut bytes := value.bytes()\n' +
				'\tfor i, b in bytes {\n' +
				"\t\tif b >= 128 { panic('py2v: swapcase of non-ASCII text is unsupported') }\n" +
				'\t\tif b.is_letter() { bytes[i] = b ^ 32 }\n' +
				'\t}\n\treturn bytes.bytestr()\n}'
		}
		'zfill' {
			'fn ${name}(text string, width int) string {\n' +
				'\tlength := text.len_utf8()\n\tif width <= length { return text }\n' +
				'\tzeros := strings.repeat(`0`, width - length)\n' +
				'\tif text.len > 0 && (text[0] == `+` || text[0] == `-`) {\n' +
				'\t\treturn text[..1] + zeros + text[1..]\n\t}\n' +
				'\treturn zeros + text\n}'
		}
		'float_sum' {
			'fn ${name}(values []f64, start f64, integer_start bool) f64 {\n' +
				'\tmut total := start\n\tmut correction := 0.0\n\tmut first := 0\n' +
				'\tif integer_start && values.len > 0 {\n\t\ttotal += values[0]\n\t\tfirst = 1\n\t}\n' +
				'\tfor value in values[first..] {\n\t\tnext := total + value\n' +
				'\t\tcorrection += if math.abs(total) >= math.abs(value) {\n' +
				'\t\t\t(total - next) + value\n\t\t} else {\n' +
				'\t\t\t(value - next) + total\n\t\t}\n\t\ttotal = next\n\t}\n' +
				'\treturn if correction != 0.0 && !math.is_inf(correction, 0) && !math.is_nan(correction) { total + correction } else { total }\n}'
		}
		'float_sum_optional' {
			sum := t.runtime_helper_name('float_sum')
			'fn ${name}(values []f64, start int) Py2vNumber {\n' +
				'\tif values.len == 0 { return Py2vNumber(start) }\n' +
				'\treturn Py2vNumber(${sum}(values, f64(start), true))\n}'
		}
		'float_sum_uniform_tagged' {
			sum := t.runtime_helper_name('float_sum')
			'fn ${name}(values []Py2vNumber) Py2vNumber {\n' +
				'\tif values.len == 0 || values[0] is int { return Py2vNumber(0) }\n' +
				'\treturn Py2vNumber(${sum}(values.map(it as f64), 0.0, true))\n}'
		}
		'typed_list_index' {
			'fn ${name}[T](items []T, needle T) !int {\n' +
				'\tindex := items.index(needle)\n' +
				"\tif index < 0 { return pyrt.raise('ValueError', pyrt.repr(pyrt.box(needle)) + ' is not in list') }\n" +
				'\treturn index\n}'
		}
		'dynamic_list_index' {
			'fn ${name}[T, U](items T, needle U) !int {\n' +
				"\treturn pyrt.to_int(pyrt.call_method(pyrt.box(items), 'index', [pyrt.box(needle)])!)\n}"
		}
		'max_integer_key' {
			'fn ${name}[T](items []T, key fn (T) int) !T {\n' +
				"\tif items.len == 0 { return pyrt.raise('ValueError', 'max() arg is an empty sequence') }\n" +
				'\tmut best := items[0]\n\tmut best_key := key(best)\n' +
				'\tfor i in 1 .. items.len {\n\t\titem := items[i]\n\t\titem_key := key(item)\n' +
				'\t\tif item_key > best_key {\n\t\t\tbest = item\n\t\t\tbest_key = item_key\n\t\t}\n' +
				'\t}\n\treturn best\n}'
		}
		'true_div' {
			'fn ${name}(a f64, b f64) f64 {\n' + '\tif b == 0 {\n' +
				"\t\tpanic('division by zero')\n" + '\t}\n' + '\treturn a / b\n' + '}'
		}
		'checked_true_div', 'checked_floor_div', 'checked_mod', 'checked_float_floor_div',
		'checked_float_mod' {
			kind_type := match kind {
				'checked_floor_div', 'checked_mod' { 'int' }
				else { 'f64' }
			}
			zero := '\tif b == 0 {\n\t\treturn IError(Py2vErrorZeroDivisionError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(message)] } } })\n\t}\n'
			body := match kind {
				'checked_true_div' { '\treturn a / b' }
				'checked_floor_div' { '\treturn math.divide_floored(a, b).quot' }
				'checked_mod' { '\treturn math.modulo_floored(a, b)' }
				'checked_float_mod' {
					'\tmut remainder := math.fmod(a, b)\n' +
						'\tif remainder == 0 { return math.copysign(0.0, b) }\n' +
						'\tif (remainder < 0) != (b < 0) { remainder += b }\n' +
						'\treturn remainder'
				}
				else {
					'\tremainder := math.fmod(a, b)\n\tmut quotient := (a - remainder) / b\n' +
						'\tif remainder != 0 && (remainder < 0) != (b < 0) { quotient-- }\n' +
						'\tif quotient == 0 { return math.copysign(0.0, a / b) }\n' +
						'\tfloored := math.floor(quotient)\n' +
						'\treturn if quotient - floored > 0.5 { floored + 1.0 } else { floored }'
				}
			}
			'fn ${name}(a ${kind_type}, b ${kind_type}, message string) !${kind_type} {\n${zero}${body}\n}'
		}
		'native_cause_text' {
			'fn ${name}(data Py2vErrorData) string {\n' +
				'\tif cause := data.cause { return cause.msg() }\n' +
				"\treturn 'None'\n}"
		}
		'checked_list_index' {
			'fn ${name}[T](items []T, index int) !T {\n' +
				'\tposition := if index < 0 { items.len + index } else { index }\n' +
				'\tif position < 0 || position >= items.len {\n' +
				"\t\treturn IError(Py2vErrorIndexError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg('list index out of range')] } } })\n" +
				'\t}\n\treturn items[position]\n}'
		}
		'bin' {
			// Python's bin(): the sign comes before the `0b` prefix.
			'fn ${name}(n i64) string {\n' + '\tif n < 0 {\n' +
				"\t\treturn '-0b' + strconv.format_uint(u64(-(n + 1)) + 1, 2)\n" + '\t}\n' +
				"\treturn '0b' + strconv.format_int(n, 2)\n" + '}'
		}
		'distinct' {
			// A Python set as an array: each value once, in order of first occurrence.
			'fn ${name}[T](a []T) []T {\n' + '\tmut b := []T{cap: a.len}\n' + '\tfor v in a {\n' +
				'\t\tif v !in b {\n' + '\t\t\tb << v\n' + '\t\t}\n' + '\t}\n' + '\treturn b\n' + '}'
		}
		else {
			panic('py2v has no run-time helper ${kind}')
		}
	}
}

// division_operand_type returns the type of `expr` as an operand of `/`: `inferred`, the
// type py2v already has for it, or else the type under a unary operator. A lambda
// parameter has none.
fn (mut t VTranspiler) division_operand_type(expr Expr, inferred string) string {
	if expr is Name && t.lambda_params[expr.id] > 0 {
		return ''
	}
	if inferred == '' && expr is UnaryOp {
		return t.division_operand_type(expr.operand, t.infer_expr_type(expr.operand))
	}
	return inferred
}

// is_v_int_type reports whether `typ` names a V integer type.
fn is_v_int_type(typ string) bool {
	return typ in ['int', 'i8', 'i16', 'i32', 'i64', 'u8', 'u16', 'u32', 'u64']
}

const native_integer_max = i64(9223372036854775807)
const native_integer_min = -native_integer_max - 1

// native_integer_type includes types that fit exactly into a signed V int.
fn native_integer_type(typ string) bool {
	return (is_v_int_type(typ) && typ != 'u64') || typ == 'bool'
}

fn unresolved_native_type(typ string) bool {
	return typ == '' || (typ.len == 1 && typ[0] >= `A` && typ[0] <= `Z`)
}

fn may_use_native_integer(typ string) bool {
	return native_integer_type(typ) || unresolved_native_type(typ)
}

// native_integer_input widens narrower operands before evaluating an operation.
fn native_integer_input(typ string, code string) string {
	return if typ == 'int' { code } else { 'int(${code})' }
}

// literal_signed_integer reads a signed integer constant without a lossy cast.
fn literal_signed_integer(expr Expr) ?i64 {
	match expr {
		Constant {
			value := expr.value
			return match value {
				int { i64(value) }
				i64 { value }
				else { none }
			}
		}
		UnaryOp {
			value := literal_signed_integer(*expr.operand)?
			if expr.op is UAdd { return value }
			if expr.op is USub && value != native_integer_min { return -value }
		}
		BinOp {
			a := literal_signed_integer(*expr.left)?
			b := literal_signed_integer(*expr.right)?
			result := fold_native_integer(integer_operation_kind(get_op_type(expr.op)), a, b)?
			if !result.wide { return result.value }
		}
		else {}
	}
	return none
}

struct NativeIntegerBounds {
	low  i64
	high i64
}

// native_integer_bounds contains only bounds backed by the current expression or loop.
fn (mut t VTranspiler) native_integer_bounds(expr Expr) NativeIntegerBounds {
	if value := literal_signed_integer(expr) {
		return NativeIntegerBounds{value, value}
	}
	if expr is Constant && expr.value is bool {
		value := i64(int(expr.value))
		return NativeIntegerBounds{value, value}
	}
	if expr is Call && expr.func is Name && expr.func.id == 'len'
		&& expr.args.len == 1 && expr.keywords.len == 0 && 'len' !in t.func_return_types
		&& !t.is_bound_in_scope('len') {
		return NativeIntegerBounds{0, native_integer_max}
	}
	if expr is Name && t.lambda_params[expr.id] == 0 {
		if bounds := t.integer_loop_bounds[t.binding_spelling(expr.id)] { return bounds }
	}
	if expr is BinOp && expr.op is BitAnd {
		for operand in [*expr.left, *expr.right] {
			if mask := literal_signed_integer(operand) {
				if mask >= 0 { return NativeIntegerBounds{0, mask} }
			}
		}
	}
	if t.infer_expr_type(expr) == 'u8' {
		return NativeIntegerBounds{0, 255}
	}
	return NativeIntegerBounds{native_integer_min, native_integer_max}
}

fn native_add_fits(a i64, b i64) bool {
	return !(b > 0 && a > native_integer_max - b) && !(b < 0 && a < native_integer_min - b)
}

fn native_sub_fits(a i64, b i64) bool {
	return !(b > 0 && a < native_integer_min + b) && !(b < 0 && a > native_integer_max + b)
}

fn native_mul_fits(a i64, b i64) bool {
	if a > 0 {
		return !(b > 0 && a > native_integer_max / b) && b >= native_integer_min / a
	}
	if a < 0 {
		return !(b > 0 && a < native_integer_min / b) && !(b < 0 && a < native_integer_max / b)
	}
	return true
}

// integer_growth_point keeps representation checks at operations that accumulate
// magnitude. The semantic handling of operators such as // is independent.
fn (mut t VTranspiler) integer_growth_point(kind string, operands []Expr, recurrence bool) bool {
	match kind {
		'power', 'parse' { return true }
		'factorial' {
			input := t.native_integer_bounds(operands[0])
			return input.low < 0 || input.high > 20
		}
		'add', 'mul', 'left_shift' {
			if kind == 'add' && !recurrence { return false }
			left := t.native_integer_bounds(operands[0])
			right := t.native_integer_bounds(operands[1])
			return match kind {
				'add' {
					!native_add_fits(left.low, right.low) || !native_add_fits(left.high, right.high)
				}
				'mul' {
					!native_mul_fits(left.low, right.low) || !native_mul_fits(left.low, right.high)
						|| !native_mul_fits(left.high, right.low) || !native_mul_fits(left.high, right.high)
				}
				else {
					right.low < 0 || right.high >= 63 || left.low < native_integer_min >> right.high
						|| left.high > native_integer_max >> right.high
				}
			}
		}
		'sum' {
			sequence := operands[0]
			if sequence !is List { return true }
			mut total := NativeIntegerBounds{}
			if operands.len > 1 { total = t.native_integer_bounds(operands[1]) }
			for item in sequence.elts {
				bounds := t.native_integer_bounds(item)
				if !native_add_fits(total.low, bounds.low) || !native_add_fits(total.high, bounds.high) {
					return true
				}
				total = NativeIntegerBounds{total.low + bounds.low, total.high + bounds.high}
			}
			return false
		}
		else { return false }
	}
}

fn reads_integer_update(expr Expr, names []string) bool {
	return match expr {
		Name { expr.id in names }
		BinOp {
			reads_integer_update(*expr.left, names) || reads_integer_update(*expr.right, names)
		}
		UnaryOp { reads_integer_update(*expr.operand, names) }
		Subscript { reads_integer_update(*expr.value, names) }
		Attribute {
			expr.value is Name && '${(expr.value as Name).id}.${expr.attr}' in names
		}
		Call {
			expr.args.any(reads_integer_update(it, names)) || expr.keywords.any(reads_integer_update(it.value, names))
		}
		else { false }
	}
}

fn growth_targets(target Expr) []string {
	return match target {
		Subscript { growth_targets(*target.value) }
		Attribute {
			if target.value is Name {
				['${(target.value as Name).id}.${target.attr}']
			} else {
				[]string{}
			}
		}
		else { for_target_names(target) }
	}
}

// A temporary copied back to a loop variable carries the same recurrence.
// Record simple copies such as f1, f2 = f2, next.
fn growth_copy_targets(body []Stmt) map[string][]string {
	mut copies := map[string][]string{}
	for stmt in body {
		if stmt !is Assign { continue }
		assignment := stmt as Assign
		if assignment.targets.len != 1 { continue }
		target := assignment.targets[0]
		value := *assignment.value
		if target is Name && value is Name {
			copies[value.id] << target.id
		} else if target is Tuple && value is Tuple && target.elts.len == value.elts.len {
			for i, name in target.elts {
				from := value.elts[i]
				if name is Name && from is Name {
					copies[from.id] << name.id
				}
			}
		}
	}
	return copies
}

// find_growth_calls records direct calls that feed their output back into an input.
fn find_growth_calls(stmts []Stmt, in_loop bool, mut inputs map[string][]int) {
	for stmt in stmts {
		match stmt {
			FunctionDef { find_growth_calls(stmt.body, false, mut inputs) }
			For, While {
				find_growth_calls(stmt.body, true, mut inputs)
				find_growth_calls(stmt.orelse, in_loop, mut inputs)
			}
			If {
				find_growth_calls(stmt.body, in_loop, mut inputs)
				find_growth_calls(stmt.orelse, in_loop, mut inputs)
			}
			Assign {
				if !in_loop || stmt.targets.len != 1 || stmt.targets[0] !is Name { continue }
				target := stmt.targets[0] as Name
				value := *stmt.value
				if value is Call && value.func is Name {
					for i, arg in value.args {
						if arg is Name && arg.id == target.id && i !in inputs[value.func.id] {
							inputs[value.func.id] << i
						}
					}
				}
			}
			else {}
		}
	}
}

// Map keyword calls back to formal argument positions before propagating
// recurrence information into function bodies. A reordered keyword call must
// not be treated as the source expression's positional argument order.
fn find_growth_keyword_calls(stmts []Stmt, in_loop bool, formals map[string][]string, mut inputs map[string][]int) {
	for stmt in stmts {
		match stmt {
			FunctionDef {
				find_growth_keyword_calls(stmt.body, false, formals, mut inputs)
			}
			For, While {
				find_growth_keyword_calls(stmt.body, true, formals, mut inputs)
				find_growth_keyword_calls(stmt.orelse, in_loop, formals, mut inputs)
			}
			If {
				find_growth_keyword_calls(stmt.body, in_loop, formals, mut inputs)
				find_growth_keyword_calls(stmt.orelse, in_loop, formals, mut inputs)
			}
			Assign {
				if !in_loop || stmt.targets.len != 1 || stmt.targets[0] !is Name {
					continue
				}
				target := (stmt.targets[0] as Name).id
				value := *stmt.value
				if value is Call && value.func is Name {
					name := (value.func as Name).id
					names := formals[name]
					for keyword in value.keywords {
						keyword_name := keyword.arg or { continue }
						if keyword.value is Name && keyword.value.id == target {
							index := names.index(keyword_name)
							if index >= 0 && index !in inputs[name] {
								inputs[name] << index
							}
						}
					}
				}
			}
			else {}
		}
	}
}

// Mark a callee's parameters when a growing integer flows through forwarding
// functions. Repeat to a fixed point, so the outer loop need not call the
// arithmetic function directly.
fn forward_growth_call(expr Expr, watched []string, formals map[string][]string, mut inputs map[string][]int) bool {
	if expr !is Call { return false }
	call := expr as Call
	if call.func !is Name { return false }
	name := (call.func as Name).id
	mut changed := false
	for index, arg in call.args {
		current := inputs[name]
		if reads_integer_update(arg, watched) && index !in current {
			inputs[name] << index
			changed = true
		}
	}
	for keyword in call.keywords {
		keyword_name := keyword.arg or { continue }
		index := formals[name].index(keyword_name)
		current := inputs[name]
		if index >= 0 && reads_integer_update(keyword.value, watched) && index !in current {
			inputs[name] << index
			changed = true
		}
	}
	return changed
}

// A forwarded integer can be returned under an if/else branch or while loop.
// Only parameter reads are considered; the callee still decides the arithmetic
// operation, and unchecked callers cannot reclassify a parameter as bounded.
fn forward_growth_in_body(body []Stmt, watched []string, formals map[string][]string, mut inputs map[string][]int) bool {
	mut changed := false
	for stmt in body {
		match stmt {
			Return {
				value := stmt.value or { continue }
				if forward_growth_call(*value, watched, formals, mut inputs) { changed = true }
			}
			Assign {
				if forward_growth_call(*stmt.value, watched, formals, mut inputs) { changed = true }
			}
			If {
				if forward_growth_in_body(stmt.body, watched, formals, mut inputs) {
					changed = true
				}
				if forward_growth_in_body(stmt.orelse, watched, formals, mut inputs) {
					changed = true
				}
			}
			For, While {
				if forward_growth_in_body(stmt.body, watched, formals, mut inputs) {
					changed = true
				}
				if forward_growth_in_body(stmt.orelse, watched, formals, mut inputs) {
					changed = true
				}
			}
			else {}
		}
	}
	return changed
}

fn propagate_growth_calls(stmts []Stmt, mut inputs map[string][]int) {
	mut functions := []FunctionDef{}
	mut formals := map[string][]string{}
	for stmt in stmts {
		if stmt is FunctionDef {
			functions << stmt
			mut names := []string{}
			for arg in stmt.args.posonlyargs { names << arg.arg }
			for arg in stmt.args.args { names << arg.arg }
			for arg in stmt.args.kwonlyargs { names << arg.arg }
			formals[stmt.name] = names
		}
	}
	find_growth_keyword_calls(stmts, false, formals, mut inputs)
	for _ in 0 .. functions.len {
		mut changed := false
		for function in functions {
			mut watched := []string{}
			names := formals[function.name]
			current := inputs[function.name]
			for index in current {
				if index < names.len { watched << names[index] }
			}
			if watched.len == 0 { continue }
			if forward_growth_in_body(function.body, watched, formals, mut inputs) {
				changed = true
			}
		}
		if !changed { break }
	}
}

struct FoldedInteger {
	value i64
	wide  bool
}

// fold_native_integer handles constant arithmetic without overflowing the emitter.
fn fold_native_integer(kind string, a i64, b i64) ?FoldedInteger {
	mut value := i64(0)
	match kind {
		'add' {
			if !native_add_fits(a, b) { return FoldedInteger{ wide: true } }
			value = a + b
		}
		'sub' {
			if !native_sub_fits(a, b) { return FoldedInteger{ wide: true } }
			value = a - b
		}
		'mul' {
			if !native_mul_fits(a, b) { return FoldedInteger{ wide: true } }
			value = a * b
		}
		'left_shift' {
			if b < 0 { return none }
			if a == 0 { return FoldedInteger{} }
			if b == 63 && a == -1 { return FoldedInteger{ value: native_integer_min } }
			if b >= 63 || a < native_integer_min >> b || a > native_integer_max >> b {
				return FoldedInteger{ wide: true }
			}
			value = a * (i64(1) << b)
		}
		'right_shift' {
			if b < 0 { return none }
			value = a >> if b >= 63 { 63 } else { b }
		}
		'floor_div', 'mod' {
			if b == 0 { return none }
			if b == -1 {
				if kind == 'mod' { return FoldedInteger{} }
				if a == native_integer_min { return FoldedInteger{ wide: true } }
			}
			r := a % b
			adjust := r != 0 && (r < 0) != (b < 0)
			value = if kind == 'mod' {
				if adjust { r + b } else { r }
			} else {
				a / b - i64(adjust)
			}
		}
		'power' {
			if b < 0 { return none }
			mut factor, mut exponent := a, b
			value = 1
			for exponent != 0 {
				if exponent & 1 != 0 {
					if !native_mul_fits(value, factor) { return FoldedInteger{ wide: true } }
					value *= factor
				}
				exponent >>= 1
				if exponent != 0 {
					if !native_mul_fits(factor, factor) { return FoldedInteger{ wide: true } }
					factor *= factor
				}
			}
		}
		else { return none }
	}
	return FoldedInteger{ value: value }
}

// native_integer_binary is the common path for native binary and augmented operations.
fn integer_operation_kind(op string) string {
	return match op {
		'Add' { 'add' }
		'Sub' { 'sub' }
		'Mult' { 'mul' }
		'FloorDiv' { 'floor_div' }
		'Mod' { 'mod' }
		'Pow' { 'power' }
		'LShift' { 'left_shift' }
		'RShift' { 'right_shift' }
		else { '' }
	}
}

fn (mut t VTranspiler) native_integer_binary(op string, left Expr, right Expr, a string, b string, loc Location, augmented bool) ?string {
	kind := integer_operation_kind(op)
	if kind == '' { return none }
	lt := t.division_operand_type(left, t.infer_expr_type(left))
	rt := t.division_operand_type(right, t.infer_expr_type(right))
	if !augmented {
		if lhs := literal_signed_integer(left) {
			if rhs := literal_signed_integer(right) {
				if folded := fold_native_integer(kind, lhs, rhs) {
					if folded.wide {
						return t.refuse_wide('line ${loc.lineno}: constant integer result exceeds the native range')
					}
					// V requires an explicit type for a literal above its implicit i32 range.
					if folded.value < -2147483648 || folded.value > 2147483647 {
						return 'int(${folded.value})'
					}
					return folded.value.str()
				}
			}
		}
	}
	recurrence := (augmented && t.loop_breaks.len > 0)
		|| reads_integer_update(left, t.integer_update_names)
		|| reads_integer_update(right, t.integer_update_names)
	growth := t.integer_growth_point(kind, [left, right], recurrence)
	if !native_integer_type(lt) || !native_integer_type(rt) {
		if kind == 'power' && unresolved_native_type(lt) && native_integer_type(rt) {
			return t.checked_integer('inferred_power', [a, native_integer_input(rt, b)], loc)
		}
		if growth && kind != 'power' && may_use_native_integer(lt) && may_use_native_integer(rt) {
			t.note_any_operator(left, right, a, b)
			return t.generic_integer(kind, op_to_symbol(op), a, b, loc)
		}
		return none
	}
	lhs := native_integer_input(lt, a)
	rhs := native_integer_input(rt, b)
	l := t.native_integer_bounds(left)
	r := t.native_integer_bounds(right)
	if kind == 'mod' && l.low >= 0 && r.low > 0 {
		return '${paren_left(lhs, 5)} % ${paren_right(rhs, 5)}'
	}
	if kind in ['floor_div', 'mod'] && (r.low > 0 || r.high < -1) {
		t.add_using('math')
		return if kind == 'floor_div' {
			'math.divide_floored[int](${lhs}, ${rhs}).quot'
		} else {
			'math.modulo_floored[int](${lhs}, ${rhs})'
		}
	}
	if kind == 'power' && r.high < 0 {
		t.add_using('math')
		return 'math.pow(f64(${lhs}), f64(${rhs}))'
	}
	if !growth && kind in ['add', 'sub', 'mul', 'left_shift'] {
		if lt != 'bool' && rt != 'bool' {
			if augmented { return none }
			symbol := op_to_symbol(op)
			prec := v_prec(symbol)
			return '${paren_left(lhs, prec)} ${symbol} ${paren_right(rhs, prec)}'
		}
	}
	if !growth && kind !in ['floor_div', 'mod']
		&& (kind != 'right_shift' || (r.low >= 0 && r.high < 63)) {
		symbol := op_to_symbol(op)
		prec := v_prec(symbol)
		return '${paren_left(lhs, prec)} ${symbol} ${paren_right(rhs, prec)}'
	}
	return t.checked_integer(kind, [lhs, rhs], loc)
}

// as_f64_argument returns `code`, an integer of type `typ`, as V accepts it for an f64
// parameter: V converts an `int` by itself and no other integer type.
fn as_f64_argument(typ string, code string) string {
	// A V int variable or literal converts by itself; an expression of Python type int
	// may be an i64 in V (`math.powi`), so it is cast.
	return if typ == 'int' && (is_simple_identifier(code) || code.bytes().all(it.is_digit())) {
		code
	} else {
		'f64(${code})'
	}
}

// A zero base and a negative numeric exponent raise Python ZeroDivisionError.
// A native floating-point power would instead print infinity, so refuse the
// statically known exception until this catchable Python operation is modeled.
fn is_zero_numeric_literal(expr Expr) bool {
	if value := literal_signed_integer(expr) { return value == 0 }
	if expr is Constant && expr.value is f64 { return expr.value == 0.0 }
	if expr is UnaryOp && (expr.op is USub || expr.op is UAdd) {
		return is_zero_numeric_literal(expr.operand)
	}
	return false
}

fn is_negative_numeric_literal(expr Expr) bool {
	if value := literal_signed_integer(expr) { return value < 0 }
	if expr is UnaryOp && expr.op is USub && expr.operand is Constant {
		c := expr.operand as Constant
		if c.value is f64 { return c.value > 0.0 }
	}
	return false
}

// is_nonzero_int_literal reports whether `expr` is an int literal other than 0, with or
// without a sign.
fn is_nonzero_int_literal(expr Expr) bool {
	return match expr {
		Constant {
			v := expr.value
			match v {
				int { v != 0 }
				i64 { v != 0 }
				else { false }
			}
		}
		UnaryOp {
			(expr.op is USub || expr.op is UAdd) && is_nonzero_int_literal(expr.operand)
		}
		else {
			false
		}
	}
}

// is_literal_zero_range_step catches a provably zero native range stride.
// A Python ValueError cannot be represented by the native range lowering.
fn is_literal_zero_range_step(expr Expr) bool {
	return match expr {
		Constant {
			value := expr.value
			match value {
				int { value == 0 }
				i64 { value == 0 }
				u64 { value == 0 }
				bool { !value }
				else { false }
			}
		}
		UnaryOp {
			(expr.op is USub || expr.op is UAdd) && is_literal_zero_range_step(expr.operand)
		}
		else { false }
	}
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
	saved_bindings := if level > 0 { t.scope_idents.clone() } else { map[string]string{} }
	saved_sum_sources := if level > 0 { t.sum_list_kinds.clone() } else { map[string]string{} }
	defer {
		if level > 0 {
			t.scope_idents = saved_bindings
			t.sum_list_kinds = saved_sum_sources
		}
	}
	mut parts := []string{}
	for i, stmt in stmts {
		saved_counter := t.proven_counter_step
		if i > 0 && stmt is For && t.emitting_function {
			t.proven_counter_step = t.stable_counter_step(stmts[i - 1], stmt)
		}
		s := t.visit_stmt(stmt)
		t.proven_counter_step = saved_counter
		t.note_sum_exit_guard(stmt)
		if i > 0 {
			if name, kind := materialized_float_sum_kind(t, stmts[i - 1], stmt) {
				t.sum_list_kinds[name] = kind
			}
		}
		if s.len == 0 {
			continue
		}
		parts << indent(s, level, '\t')
	}
	return parts.join('\n')
}

fn (mut t VTranspiler) note_sum_source(name string, value Expr) {
	if value is GeneratorExp || python_numeric_arg_list_kind(t, value) == 'one_shot_generator' {
		t.sum_list_kinds[name] = 'one_shot_generator'
		return
	}
	if value is List || value is Tuple || value is ListComp {
		t.sum_list_kinds[name] = python_numeric_arg_list_kind(t, value)
		return
	}
	if value is BinOp && value.op is Mult {
		kind := python_numeric_arg_list_kind(t, value)
		if kind in ['float', 'maybe_float', 'empty'] {
			t.sum_list_kinds[name] = kind
			return
		}
	}
	if value is Call {
		kind := python_numeric_arg_list_kind(t, value)
		if kind in ['uniform_sum_array', 'float', 'maybe_float', 'int'] {
			t.sum_list_kinds[name] = kind
			return
		}
	}
	kind := python_number_kind(t, value, t.sum_list_kinds)
	if kind in ['float', 'int'] {
		t.sum_list_kinds[name] = '${kind}_value'
	} else {
		t.sum_list_kinds.delete(name)
	}
}

fn (mut t VTranspiler) note_sum_exit_guard(stmt Stmt) {
	if stmt !is If { return }
	guard := stmt as If
	if guard.orelse.len != 0 || guard.body.len != 1
		|| !(guard.body[0] is Raise || guard.body[0] is Return) {
		return
	}
	test := *guard.test
	if test is UnaryOp && test.op is Not {
		sequence := t.sum_nonempty_test_sequence(*test.operand) or { return }
		if sequence is Name && !t.extra_mut_vars[sequence.id]
			&& t.infer_expr_type(sequence).starts_with('[]') {
			name := sequence.id
			t.sum_list_kinds[name] = match t.sum_list_kinds[name] {
				'float', 'maybe_float' { 'float' }
				'float_lists' { 'float_lists' }
				else { 'nonempty' }
			}
		}
	}
}

fn (t &VTranspiler) sum_nonempty_test_sequence(expr Expr) ?Expr {
	if expr is Name { return expr }
	if expr is Compare && expr.ops.len == 1 && expr.ops[0] is Gt {
		value := literal_signed_integer(expr.comparators[0]) or { return none }
		left := *expr.left
		if value == 0 && left is Call && left.func is Name && left.func.id == 'len'
			&& 'len' !in t.module_functions && !t.is_bound_in_scope('len')
			&& left.args.len == 1 && left.keywords.len == 0 {
			return left.args[0]
		}
	}
	return none
}

// stable_counter_step proves the pattern of a local zero-based count followed by
// a scan whose body can increment it once and cannot change the sequence's length.
fn (mut t VTranspiler) stable_counter_step(prior Stmt, loop For) string {
	if prior !is Assign || loop.body.len != 1 {
		return ''
	}
	assignment := prior as Assign
	if assignment.targets.len != 1 { return '' }
	counter := assignment.targets[0]
	if counter !is Name || counter.id in t.global_vars || counter.id in for_target_names(loop.target)
		|| t.infer_expr_type(counter) != 'int' {
		return ''
	}
	initial := literal_signed_integer(*assignment.value) or { return '' }
	if initial != 0 || loop.iter !is Name {
		return ''
	}
	sequence := t.infer_expr_type(loop.iter)
	if !sequence.starts_with('[]') && sequence != 'string' {
		return ''
	}
	mut step := loop.body[0]
	if step is If && step.body.len == 1 && step.orelse.len == 0
		&& t.counter_condition_is_pure(*step.test) {
		step = step.body[0]
	}
	if step is AugAssign && step.op is Add && step.target is Name && step.target.id == counter.id {
		increment := literal_signed_integer(step.value) or { return '' }
		if increment == 1 {
			return step.loc.str()
		}
	}
	return ''
}

// counter_condition_is_pure excludes truth tests and comparisons that can call user code.
fn (mut t VTranspiler) counter_condition_is_pure(expr Expr) bool {
	if expr is Compare {
		return expr.ops.all(it is Eq || it is NotEq || it is Lt || it is LtE || it is Gt || it is GtE)
			&& t.has_builtin_type(*expr.left) && t.runs_no_code(*expr.left)
			&& expr.comparators.all(t.has_builtin_type(it) && t.runs_no_code(it))
	}
	return t.has_builtin_type(expr) && t.runs_no_code(expr)
}

// visit_return emits V code for a Return statement.
pub fn (mut t VTranspiler) visit_return(node Return) string {
	if t.defer_depth > 0 {
		return 'py2v_unsupported_return_from_finally()'
	}
	if val := node.value {
		if t.current_return_type == '[]Py2vNumber' && val is List {
			return 'return ${t.numeric_choice_list(val)}'
		}
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
		mut prelude := []string{}
		bound := t.bind_chain_middle(val, mut prelude)
		saved_updates := t.integer_update_names
		t.integer_update_names = t.integer_return_names
		defer { t.integer_update_names = saved_updates }
		value := t.visit_integer_boundary(bound, .scalar_return, t.current_return_type)
		output := if t.current_return_type == 'Py2vNumber' {
			t.numeric_choice_value(bound, value)
		} else {
			value
		}
		prelude << 'return ${output}'
		return prelude.join('\n')
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
				// Unsupported deletion is emitted only as a comment. Visiting
				// the sliced target would register an otherwise unused helper.
				return [
					'// del ${t.visit_expr(sub.value)}[...]  // unsupported: slice deletion',
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
		Pass {
			if stmt.list_identity_error != '' {
				return t.list_identity_refusal(stmt.list_identity_error)
			}
			return '// pass'
		}
		Break { return t.visit_break() }
		Continue { return 'continue' }
		TypeAlias { return t.visit_type_alias(stmt) }
		Match { return t.visit_match(stmt) }
	}
}

// WideSink lists the immediate consumers allowed to read a proven Python word.
enum WideSink {
	unapproved
	scalar_storage
	scalar_argument
	scalar_return
	bounded_bits
	integer_comparison
	decimal_text
	binary_text
	hexadecimal_text
	bit_measure
}

const large_integer_type = 'py2v_big.Integer'

fn wide_sink_allowed(sink WideSink, typ string, unbounded bool) bool {
	if unbounded {
		return sink == .decimal_text || (sink == .scalar_storage && typ == large_integer_type)
	}
	return match sink {
		.unapproved { false }
		.scalar_storage, .scalar_argument, .scalar_return { typ == 'u64' }
		.bounded_bits, .integer_comparison, .decimal_text, .binary_text, .hexadecimal_text,
		.bit_measure {
			true
		}
	}
}

// visit_expr defaults to refusal. An approved consumer passes a permit for
// exactly one operand. Rendering that operand does not authorize its children.
pub fn (mut t VTranspiler) visit_expr(expr Expr) string {
	return t.visit_expr_at(expr, .unapproved, '')
}

fn (mut t VTranspiler) visit_expr_at(expr Expr, sink WideSink, typ string) string {
	target := (expr is Name && expr.ctx is Store) || (expr is Attribute && expr.ctx is Store)
	if !target && t.has_wide_container_type(expr) {
		return t.refuse_wide('unsigned values in containers are unsupported')
	}
	if !target && t.has_large_integer(expr) && !wide_sink_allowed(sink, typ, true) {
		return t.refuse_wide('integer outside the native range needs exact decimal text or storage')
	}
	if !target && t.has_u64_bits(expr) && !wide_sink_allowed(sink, typ, false) {
		return t.refuse_wide('this use has no proven unsigned lowering')
	}
	if get_v_annotation(expr).contains('pyrt.ListRef[') { t.add_using('pyrt') }

	match expr {
		Constant { return t.visit_constant(expr) }
		Name { return t.visit_name(expr) }
		BinOp { return t.visit_binop(expr) }
		UnaryOp { return t.visit_unaryop(expr) }
		BoolOp { return t.visit_boolop(expr) }
		Compare { return t.visit_compare(expr) }
		Call { return t.visit_call_at(expr, sink, typ) }
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

fn (mut t VTranspiler) visit_integer_boundary(expr Expr, sink WideSink, typ string) string {
	return t.integer_boundary(expr, t.visit_expr_at(expr, sink, typ), typ)
}

fn proven_word_parameter(arg Arg) bool {
	if ann := arg.annotation {
		return ann is Name && ann.id == 'u64'
	}
	return arg.v_annotation == 'u64'
}

fn has_word_return(node FunctionDef) bool {
	if ret := node.returns {
		return ret is Name && ret.id == 'u64'
	}
	return node.v_annotation == 'u64'
}

fn register_wide_exports(parsed map[string]Module, mut registry ModuleRegistry) {
	mut scan := new_transpiler()
	for path, mod in parsed {
		for stmt in mod.body {
			match stmt {
				Assign {
					if stmt.targets.len == 1 && stmt.targets[0] is Name {
						kind := if scan.has_u64_bits(stmt.value) {
							'value'
						} else if scan.has_large_integer(stmt.value) {
							'large'
						} else {
							''
						}
						if kind != '' {
							registry.wide_exports['${kind}:${path}.${stmt.targets[0].id}'] = true
						}
					}
				}
				AnnAssign {
					if stmt.target is Name && stmt.annotation is Name && stmt.annotation.id == 'u64' {
						registry.wide_exports['value:${path}.${stmt.target.id}'] = true
					}
				}
				FunctionDef {
					if has_word_return(stmt) {
						registry.wide_exports['call:${path}.${stmt.name}'] = true
					}
				}
				ClassDef {
					v_module := registry.lookup(path).v_module
					v_name := registry.class_names['${path}.${stmt.name}'] or { emitted_class_name(stmt.name) }
					for name, typ in stmt.declarations {
						if typ == 'u64' {
							registry.wide_exports['field:${path}.${stmt.name}.${name}'] = true
							registry.wide_members['field:${v_module}.${v_name}.${name}'] = true
						}
					}
					for method in stmt.body {
						if method is FunctionDef && has_word_return(method) {
							registry.wide_exports['method:${path}.${stmt.name}.${method.name}'] = true
							registry.wide_members['method:${v_module}.${v_name}.${method.name}'] = true
						}
					}
				}
				else {}
			}
		}
	}
}

fn (t VTranspiler) imported_word(expr Expr, kind string) bool {
	return t.registry.wide_exports.len > 0
		&& t.registry.has_wide_export(t.init_python_path(expr), kind)
}

fn (t VTranspiler) wide_call_argument(node Call, fname string, param_type string) WideSink {
	if param_type == 'u64' && node.func is Name {
		return .scalar_argument
	}
	if node.func !is Name || node.func.id != fname || t.is_bound_in_scope(fname)
		|| fname in t.call_signatures || fname in t.func_return_types || fname in t.init_import_aliases {
		return .unapproved
	}
	if fname == 'print' {
		return if node.keywords.len == 0 { .decimal_text } else { .unapproved }
	}
	if node.args.len != 1 || node.keywords.len != 0 {
		return .unapproved
	}
	return match fname {
		'str' { WideSink.decimal_text }
		'bin' { WideSink.binary_text }
		'hex' { WideSink.hexadecimal_text }
		else { WideSink.unapproved }
	}
}

// A string produced from a proven wide value retains that provenance for
// secondary formatting decisions, even though its V type is plain string.
fn (mut t VTranspiler) is_wide_text_source(expr Expr) bool {
	if expr is Call && expr.func is Name && expr.args.len == 1
		&& expr.keywords.len == 0 && expr.func.id in ['str', 'repr', 'bin', 'hex', 'oct'] {
		return t.has_u64_bits(expr.args[0]) || t.has_large_integer(expr.args[0])
	}
	return false
}

// visit_function_def_or_closure keeps lexical function definitions inside their owner.
fn (mut t VTranspiler) visit_function_def_or_closure(node FunctionDef) string {
	mut nl_names := []string{}
	for stmt in node.body {
		if stmt is Nonlocal {
			nl_names << (stmt as Nonlocal).names
		}
	}
	if node.is_nested || nl_names.len > 0 {
		return t.visit_closure_from_funcdef(node, nl_names)
	}
	return t.visit_function_def(node)
}

// visit_closure_from_funcdef keeps a nested definition at the point Python binds it.
// The frontend supplies lexical captures; collecting names from generated code would
// accidentally capture modules, builtins, and locals of the inner function.
fn (mut t VTranspiler) visit_closure_from_funcdef(node FunctionDef, nl_names []string) string {
	name := escape_local_decl(node.name)
	bind := t.bind_op(name)
	saved_types := t.var_types.clone()
	saved_locals := t.local_idents.clone()
	saved_scope := t.scope_idents.clone()
	saved_params := t.param_idents.clone()
	saved_renames := t.renamed_idents.clone()
	saved_loops := t.loop_idents.clone()
	saved_loop_prelude := t.loop_prelude.clone()
	saved_integer_loop_bounds := t.integer_loop_bounds.clone()
	saved_breaks := t.loop_breaks.clone()
	saved_escaped := t.escaped_identifiers.clone()
	saved_condition_vars := t.condition_walrus_vars
	saved_condition_types := t.condition_walrus_types
	saved_condition_initial := t.condition_walrus_initial
	saved_condition_order := t.condition_walrus_order
	saved_return_count := t.current_return_count
	saved_return_type := t.current_return_type
	saved_result := t.fn_returns_result
	saved_entry := t.in_entry
	saved_error_guard := t.active_error_guard
	saved_init_aliases := t.init_import_aliases.clone()
	saved_init_captures := t.init_capture_locals.clone()
	defer {
		t.var_types = saved_types
		t.local_idents = saved_locals
		t.local_idents[node.name] = name
		t.scope_idents = saved_scope
		t.scope_idents[name] = node.name
		t.param_idents = saved_params
		t.renamed_idents = saved_renames
		t.loop_idents = saved_loops
		t.loop_prelude = saved_loop_prelude
		t.integer_loop_bounds = saved_integer_loop_bounds
		t.loop_breaks = saved_breaks
		t.escaped_identifiers = saved_escaped
		t.condition_walrus_vars = saved_condition_vars
		t.condition_walrus_types = saved_condition_types
		t.condition_walrus_initial = saved_condition_initial
		t.condition_walrus_order = saved_condition_order
		t.current_return_count = saved_return_count
		t.current_return_type = saved_return_type
		t.fn_returns_result = saved_result
		t.in_entry = saved_entry
		t.active_error_guard = saved_error_guard
		t.init_import_aliases = saved_init_aliases
		t.init_capture_locals = saved_init_captures
		t.init_capture_locals[node.name] = true
	}

	mut captures := []string{}
	mut capture_params := []string{}
	mut capture_locals := map[string]string{}
	mut capture_setup := []string{}
	mut default_values := []string{}
	mut default_setup := []string{}
	mut decorator_values := []string{}
	mut refusal := node.capture_refusal
	capture_names := if node.is_nested { node.capture_names } else { nl_names }
	for expr in node.args.defaults {
		code := t.visit_expr(expr)
		if expr is Constant {
			default_values << code
		} else {
			// Python evaluates defaults once when it executes the definition.
			// Do not re-evaluate them at each call or capture their later bindings.
			tmp := t.new_tmp('default')
			default_setup << '${tmp} := ${code}'
			default_values << tmp
		}
	}
	for decorator in node.decorator_list {
		decorator_values << t.visit_expr(decorator)
		refusal = 'decorator'
	}
	for py_name in capture_names {
		if py_name in saved_loops || py_name in saved_renames {
			refusal = 'loop_capture'
		} else if py_name !in saved_locals && py_name !in saved_types && !t.is_bound_in_scope(py_name)
			&& !(py_name == 'self' && t.current_class_name != '') {
			refusal = 'forward_capture'
		}
	}
	for py_name in capture_names {
		local := t.visit_name(Name{ id: py_name })
		mut typ := t.map_type(node.capture_types[py_name] or { saved_types[py_name] })
		if typ == '' || typ == 'auto' { typ = 'Any' }
		if refusal != '' {
			formal := escape_local_decl(py_name)
			capture_params << '${formal} ${typ}'
			capture_locals[py_name] = formal
		} else {
			// V's `mut` scalar capture is a copy. Capture the address instead so
			// siblings, nonlocal writes, and the enclosing function share one binding.
			pointer := t.new_tmp('capture')
			capture_setup << '${pointer} := &(${local})'
			captures << pointer
			capture_locals[py_name] = '(*${pointer})'
		}
	}

	t.local_idents = capture_locals.clone()
	t.scope_idents = map[string]string{}
	for py_name, spelling in capture_locals { t.scope_idents[spelling] = py_name }
	t.param_idents = map[string]bool{}
	t.renamed_idents = map[string]string{}
	t.loop_idents = map[string]bool{}
	t.loop_prelude = []string{}
	t.integer_loop_bounds.clear()
	t.loop_breaks = []LoopBreak{}
	t.escaped_identifiers = map[string]bool{}
	t.condition_walrus_vars = map[string]bool{}
	t.condition_walrus_types = map[string]string{}
	t.condition_walrus_initial = map[string]string{}
	t.condition_walrus_order = []string{}
	t.current_return_count = 0
	t.fn_returns_result = false
	t.in_entry = false
	t.active_error_guard = 0
	t.init_capture_locals = init_function_capture_names(node)
	for py_name in capture_names { t.init_capture_locals[py_name] = true }

	mut params := node.args.posonlyargs.clone()
	params << node.args.args
	params << node.args.kwonlyargs
	mut declarations := []string{}
	mut param_types := []string{}
	mut copies := []string{}
	mut mut_indices := []int{}
	for i, arg in params {
		local := escape_local_decl(arg.arg)
		mut typ := t.typename_from_annotation(arg.annotation)
		if typ == '' { typ = t.map_type(arg.v_annotation) }
		if typ == '' || typ == 'auto' { typ = 'Any' }
		t.local_idents[arg.arg] = local
		t.scope_idents[local] = arg.arg
		t.param_idents[arg.arg] = arg.arg in node.mutable_vars
		t.var_types[arg.arg] = typ
		mut incoming := local
		if arg.arg in node.mutable_vars {
			if !arg.is_mutable && typ.starts_with('[]') {
				incoming = t.new_tmp('${arg.arg}_in')
				copies << 'mut ${local} := ${incoming}.clone()'
			} else if typ in v_value_param_types || for_rebinds_parameter(node.body, arg.arg) {
				incoming = t.new_tmp('${arg.arg}_in')
				copies << 'mut ${local} := ${incoming}'
			} else {
				incoming = 'mut ${local}'
				mut_indices << i
			}
		}
		declarations << '${incoming} ${typ}'
		param_types << if typ == 'u64' && !proven_word_parameter(arg) { '' } else { typ }
	}
	if kwarg := node.args.kwarg {
		local := escape_local_decl(kwarg.arg)
		t.local_idents[kwarg.arg] = local
		declarations << '${local} map[string]Any'
	}
	if node.is_generator {
		typ := t.infer_generator_yield_type(node.body)
		if node.args.vararg != none {
			declarations.prepend('ch chan ${typ}')
		} else {
			declarations << 'ch chan ${typ}'
		}
		t.generator_signatures[node.name] = GeneratorSignature{typ, node.args.vararg != none, node.args}
	}
	if vararg := node.args.vararg {
		local := escape_local_decl(vararg.arg)
		mut typ := t.typename_from_annotation(vararg.annotation)
		if typ == '' {
			typ = 'Any'
		}
		t.local_idents[vararg.arg] = local
		declarations << '${local} ...${typ}'
	}
	mut ret := ''
	if !node.is_void && !node.is_generator {
		if annotation := node.returns {
			ret = v_return_type(t.typename_from_annotation(*annotation))
		} else {
			ret = t.map_type(node.v_annotation)
			if ret == '' || ret == 'auto' { ret = 'Any' }
		}
		if ret.starts_with('(') { t.current_return_count = ret.count(',') + 1 }
	}
	t.func_return_types[node.name] = ret
	t.current_return_type = ret
	t.func_param_types[node.name] = param_types
	t.mut_param_indices[node.name] = mut_indices
	t.func_defaults[node.name] = default_values.clone()
	t.func_param_count[node.name] = node.args.posonlyargs.len + node.args.args.len
	mut prefix := if default_setup.len > 0 { default_setup.join('\n') + '\n' } else { '' }
	if node.is_recursive {
		if refusal == '' {
			prefix += "mut ${name} := fn (${declarations.join(', ')}) ${ret} { panic('uninitialized recursive closure') }\n"
			captures << 'mut ${name}'
			t.local_idents[node.name] = name
		} else {
			capture_params << '${name} fn (${param_types.join(', ')}) ${ret}'
		}
	}
	// A nested definition's signature belongs to this lexical scope. Keep the
	// current function's metadata, and discard metadata introduced by its body.
	saved_nested_defaults := t.func_defaults.clone()
	saved_nested_counts := t.func_param_count.clone()
	saved_nested_params := t.func_param_types.clone()
	saved_nested_returns := t.func_return_types.clone()
	saved_nested_mut := t.mut_param_indices.clone()
	saved_nested_generators := t.generator_signatures.clone()
	defer {
		t.func_defaults = saved_nested_defaults
		t.func_param_count = saved_nested_counts
		t.func_param_types = saved_nested_params
		t.func_return_types = saved_nested_returns
		t.mut_param_indices = saved_nested_mut
		t.generator_signatures = saved_nested_generators
	}

	// Defaults use the parent context; the nested body owns its cleanup state.
	saved_finally := t.exit_finally_bodies.clone()
	saved_defer_depth := t.defer_depth
	t.exit_finally_bodies = [][]Stmt{}
	t.defer_depth = 0
	defer {
		t.exit_finally_bodies = saved_finally
		t.defer_depth = saved_defer_depth
	}

	t.prepare_condition_walruses(node.condition_walrus_names, params)
	mut body := []string{}
	if node.is_generator { body << 'defer { ch.close() }' }
	body << copies
	for i, stmt in node.body {
		if stmt is Nonlocal { continue }
		if i == 0 && stmt is ExprStmt && stmt.value is Constant && stmt.value.value is string {
			continue
		}
		body << t.visit_stmt(stmt)
	}
	condition_declarations := t.condition_walrus_declarations()
	if condition_declarations != '' { body.prepend(condition_declarations) }
	body_code := t.indent_code(body.filter(it != '').join('\n'), 1)
	if refusal != '' {
		// Keep the entire implementation as a function argument. The unresolved call
		// refuses unsupported capture timing instead of omitting the function's body.
		capture_params << declarations
		mut refusal_values := default_values.clone()
		refusal_values << decorator_values
		defaults := if refusal_values.len > 0 { ', ' + refusal_values.join(', ') } else { '' }
		return '${prefix}${name} ${bind} py2v_unsupported_closure_${refusal}(fn (${capture_params.join(', ')}) ${ret} {\n${body_code}\n}${defaults})'
	}
	if capture_setup.len > 0 {
		prefix += capture_setup.join('\n') + '\n'
	}
	capture_text := if captures.len > 0 { ' [${captures.join(', ')}]' } else { '' }
	op := if node.is_recursive { '=' } else { bind }
	return '${prefix}${name} ${op} fn${capture_text} (${declarations.join(', ')}) ${ret} {\n${body_code}\n}'
}

// visit_function_def emits V code for a Python FunctionDef node.
pub fn (mut t VTranspiler) visit_function_def(node FunctionDef) string {
	previous_return_names := t.integer_return_names
	t.integer_return_names = []
	defer { t.integer_return_names = previous_return_names }
	if !node.is_class_method && !node.is_nested {
		mut args := node.args.posonlyargs.clone()
		args << node.args.args
		for index in t.integer_return_inputs[node.name] {
			if index < args.len {
				t.integer_return_names << args[index].arg
			}
		}
	}
	if !node.is_class_method {
		t.init_import_aliases.delete(node.name)
	}
	if !node.is_class_method && !node.is_nested {
		renamed := t.emitted_fn_name(node.name)
		if renamed != node.name {
			return t.visit_function_def(FunctionDef{
				...node
				name: renamed
			})
		}
	}
	was_emitting_function := t.emitting_function
	t.emitting_function = true
	defer { t.emitting_function = was_emitting_function }
	saved_condition_vars := t.condition_walrus_vars
	saved_condition_types := t.condition_walrus_types
	saved_condition_initial := t.condition_walrus_initial
	saved_condition_order := t.condition_walrus_order
	t.condition_walrus_vars = map[string]bool{}
	t.condition_walrus_types = map[string]string{}
	t.condition_walrus_initial = map[string]string{}
	t.condition_walrus_order = []string{}
	defer {
		t.condition_walrus_vars = saved_condition_vars
		t.condition_walrus_types = saved_condition_types
		t.condition_walrus_initial = saved_condition_initial
		t.condition_walrus_order = saved_condition_order
	}
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
	saved_sum_list_kinds := t.sum_list_kinds.clone()
	t.sum_list_kinds = map[string]string{}
	saved_sum_array_binding := t.sum_array_binding
	t.sum_array_binding = ''
	defer { t.sum_array_binding = saved_sum_array_binding }
	saved_escaped_identifiers := t.escaped_identifiers.clone()
	t.escaped_identifiers = map[string]bool{}
	saved_local_idents := t.local_idents.clone()
	t.local_idents = map[string]string{}
	saved_current_class := t.current_class_name
	saved_classmethod := t.current_classmethod
	saved_returns_result := t.fn_returns_result
	saved_entry := t.in_entry
	saved_error_guard := t.active_error_guard
	t.fn_returns_result = node.raises
	t.in_entry = !t.emit_pub && !node.is_class_method && !node.is_nested && node.name == 'main'
	t.active_error_guard = 0
	defer {
		t.fn_returns_result = saved_returns_result
		t.in_entry = saved_entry
		t.active_error_guard = saved_error_guard
	}
	t.current_classmethod = node.is_class_method && node.decorator_kind == 'classmethod'
	saved_init_aliases := t.init_import_aliases.clone()
	saved_init_captures := t.init_capture_locals.clone()
	t.init_capture_locals = init_function_capture_names(node)
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
	if node.name == 'main' && !t.emit_pub {
		// Script module statements are injected before this main body. Keep
		// their walrus types when the guard body later prints those bindings.
		for name, typ in saved_condition_types { func_var_types[name] = typ }
	}
	t.var_types = func_var_types.clone()
	// A parameter or local of an enclosing function is not in scope here.
	saved_scope_idents := t.scope_idents
	t.scope_idents = map[string]string{}
	saved_param_idents := t.param_idents
	t.param_idents = map[string]bool{}
	saved_any_params := t.any_parameter_names
	t.any_parameter_names = map[string]bool{}
	defer { t.any_parameter_names = saved_any_params }

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
		// V reserves a few names for its own intrinsics, so a function declared
		// under one of them can never be called.
		if !node.is_class_method {
			emit_name = escape_fn_name(emit_name)
		}
	}
	// V type methods implement direct calls to Python class and static methods.
	if node.is_class_method && node.decorator_kind in ['classmethod', 'staticmethod'] {
		member := if node.dunder_op.starts_with('py2v_overload_') { emit_name } else { node.name }
		owner := t.local_class_name(node.class_name)
		emit_name = if !t.nominal_enums[node.class_name]
			&& '${t.current_dotted}.${node.class_name}' in t.registry.class_names {
			'${to_symbol_ident(owner)}_${escape_leading_underscore(member)}'
		} else {
			'${owner}.${escape_keyword(escape_leading_underscore(member))}'
		}
		dunder_comment = '// @${node.decorator_kind}\n'
	}

	// Binary/comparison operator overloads need value receivers in V, and V
	// requires both operands of an operator to have the same type.
	is_binop_dunder := node.dunder_op in ['+', '-', '*', '/', '%', '==', '!=', '<', '<=', '>',
		'>=']
	mut emitted_receiver_type := t.local_class_name(node.class_name)
	if tp := t.class_type_params[node.class_name] {
		if tp.len > 0 {
			emitted_receiver_type = '${emitted_receiver_type}[${tp.join(', ')}]'
		}
	}

	// Handle class method receiver (skip for staticmethod / classmethod)
	if node.is_class_method && node.decorator_kind !in ['staticmethod', 'classmethod'] {
		base_receiver := t.local_class_name(node.class_name)
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
		} else if node.class_name in t.ref_classes {
			// `return self` and `node = self` hand out the object, not a copy.
			signature << '(self &${emitted_receiver})'
		} else {
			signature << '(self ${emitted_receiver})'
		}
	}

	// Process arguments
	mut args_strs := []string{}
	mut generics := []string{}
	mut mut_indices := []int{} // Track which parameter indices are mutable
	mut param_copies := []string{} // `mut name := incoming` for rebound value parameters
	mut param_idx := 0

	mut positional_args := node.args.posonlyargs.clone()
	positional_args << node.args.args
	sum_parameter_kinds := if !node.is_class_method && !node.is_nested {
		t.sum_parameter_kinds[node.name]
	} else {
		[]string{}
	}
	for i, arg in positional_args {
		if arg.arg == 'self' {
			continue
		}
		// V type methods do not take the implicit class parameter.
		if i == 0 && node.decorator_kind == 'classmethod' {
			continue
		}
		// A parameter is already bound, so a `for` variable of the same name
		// must take a fresh one.
		t.param_idents[arg.arg] = arg.arg in node.mutable_vars
		kind := sum_parameter_kinds[i] or { '' }
		if kind != '' && !arg.is_mutable && arg.arg !in node.mutable_vars {
			t.sum_list_kinds[arg.arg] = kind
		}

		mut typename := ''
		if ann := arg.annotation {
			typename = t.typename_from_annotation(*ann)
		}
		// A parameter the frontend could only type by inference, for example one
		// that exists solely to fill an annotated field.
		if typename == '' && arg.v_annotation != '' {
			typename = t.map_type(arg.v_annotation)
		}
		if typename == '[]f64' && kind == 'int' {
			typename = '[]int'
		}
		if typename == '[]f64' && t.numeric_array_results.len > 0 && !node.is_class_method {
			typename = '[]Py2vNumber'
		}

		// Python commonly leaves the operand of a comparison unannotated, which
		// would otherwise become `Any`; V needs the receiver type there.
		if typename == '' && is_binop_dunder && node.is_class_method {
			typename = emitted_receiver_type
		}

		mut arg_name := escape_local_decl(arg.arg)
		t.local_idents[arg.arg] = arg_name
		t.scope_idents[arg_name] = arg.arg
		// Track identifiers escaped due to built-in type name conflicts
		if arg.arg in v_builtin_types {
			t.escaped_identifiers[arg.arg] = true
		}
		// Check if this argument is mutable
		if arg.arg in node.mutable_vars {
			optional_value := !node.is_class_method && arg.arg !in node.condition_walrus_names
				&& is_optional_value_type(typename)
			local_value := for_rebinds_parameter(node.body, arg.arg) && (typename in ['', 'Any']
				|| typename.starts_with('[]') || typename.starts_with('map['))
			if typename in v_value_param_types && arg.arg in node.condition_walrus_names {
				// The walrus lowering copies this parameter itself.
			} else if !arg.is_mutable && typename.starts_with('[]') {
				incoming := t.new_tmp('${arg.arg}_in')
				param_copies << 'mut ${arg_name} := ${incoming}.clone()'
				arg_name = incoming
			} else if typename in v_value_param_types || optional_value || local_value
				|| typename.starts_with('&pyrt.ListRef[') {
				// Rebinding a number, string or bool parameter is local in Python, and V
				// has no `mut` for these or their options: it arrives under another name and the
				// body starts with a mutable local that has the source's name.
				incoming := t.new_tmp('${arg.arg}_in')
				param_copies << if typename.starts_with('&pyrt.ListRef[') {
					'mut ${arg_name} := unsafe { ${incoming} }'
				} else {
					'mut ${arg_name} := ${incoming}'
				}
				arg_name = incoming
			} else {
				arg_name = 'mut ${arg_name}'
				mut_indices << param_idx
			}
		}

		if typename == '' {
			// V functions require explicit parameter types.
			typename = 'Any'
		} else {
			// A single uppercase letter is a generic, alone (`T`) or inside a type (`[]T`)
			for letter in generic_letters(typename) {
				if letter !in generics {
					generics << letter
				}
			}
		}

		args_strs << '${arg_name} ${typename}'
		if typename == 'Any' {
			t.any_parameter_names[arg.arg] = true
		}
		if !node.is_class_method {
			t.func_param_types[node.name] << if typename == 'u64' && !proven_word_parameter(arg) {
				''
			} else {
				typename
			}
		}
		// Track parameter type for return type inference
		if typename != '' && typename != 'Any' && !(typename.len == 1 && typename[0] >= `A`
			&& typename[0] <= `Z`) {
			t.var_types[arg.arg] = typename
		}
		param_idx++
	}

	// Python keyword-only args come after `*args`, but V requires the variadic
	// parameter to be last, so emit them here, before it.
	for kwonly in node.args.kwonlyargs {
		mut kwname := escape_local_decl(kwonly.arg)
		t.local_idents[kwonly.arg] = kwname
		t.scope_idents[kwname] = kwonly.arg
		t.param_idents[kwonly.arg] = kwonly.arg in node.mutable_vars
		mut kwtype := 'Any'
		if ann := kwonly.annotation {
			kwtype = t.typename_from_annotation(*ann)
			if kwtype == '' {
				kwtype = '?Any'
			}
		}
		t.var_types[kwonly.arg] = kwtype
		if kwonly.arg in node.mutable_vars {
			if !kwonly.is_mutable && kwtype.starts_with('[]') {
				incoming := t.new_tmp('${kwonly.arg}_in')
				param_copies << 'mut ${kwname} := ${incoming}.clone()'
				kwname = incoming
			} else if kwtype in v_value_param_types || for_rebinds_parameter(node.body, kwonly.arg) {
				incoming := t.new_tmp('${kwonly.arg}_in')
				param_copies << 'mut ${kwname} := ${incoming}'
				kwname = incoming
			} else {
				kwname = 'mut ${kwname}'
			}
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
		// No trailing comment: a `//` after the last parameter would swallow the
		// opening brace of the function body.
		local := escape_local_decl(kwarg.arg)
		t.local_idents[kwarg.arg] = local
		t.scope_idents[local] = kwarg.arg
		t.param_idents[kwarg.arg] = false
		t.var_types[kwarg.arg] = 'map[string]Any'
		args_strs << '${local} map[string]Any'
	}

	// Handle vararg (*args)
	if vararg := node.args.vararg {
		mut typename := ''
		if ann := vararg.annotation {
			typename = t.typename_from_annotation(*ann)
		}
		if typename.starts_with('[]') {
			typename = '...' + typename[2..]
		} else if typename == '' {
			typename = '...Any'
		} else {
			typename = '...' + typename
		}
		local := escape_local_decl(vararg.arg)
		t.local_idents[vararg.arg] = local
		t.scope_idents[local] = vararg.arg
		t.param_idents[vararg.arg] = false
		t.var_types[vararg.arg] = '[]' + typename.trim_left('.')
		args_strs << '${local} ${typename}'
	}

	// For generator functions, add channel parameter
	if node.is_generator {
		yield_type := t.infer_generator_yield_type(node.body)
		channel_first := node.args.vararg != none
		if channel_first {
			// V requires the remaining Python arguments to be last.
			args_strs.prepend('ch chan ${yield_type}')
		} else {
			args_strs << 'ch chan ${yield_type}'
		}
		t.generator_signatures[node.name] = GeneratorSignature{yield_type, channel_first, node.args}
	}

	// A function names its generic types; a method takes them from its receiver.
	generic_list := if generics.len > 0 && !node.is_class_method {
		'[${generics.join(', ')}]'
	} else {
		''
	}
	signature << '${emit_name}${generic_list}(${args_strs.join(', ')})'

	// Pre-scan body to populate var_types for return type inference
	// (no-op in current backend)
	_ = node.body

	// Return type
	saved_return_count := t.current_return_count
	saved_return_type := t.current_return_type
	t.current_return_count = 0
	t.current_return_type = ''
	if !t.emit_pub && !node.is_class_method && !node.is_nested && node.body.len > 0
		&& node.body.last() is Return {
		parameter_proofs := t.sum_list_kinds.clone()
		for i, stmt in node.body {
			if i > 0 {
				if name, kind := materialized_float_sum_kind(t, node.body[i - 1], stmt) {
					t.sum_list_kinds[name] = kind
				}
			}
		}
		last := node.body.last() as Return
		if value := last.value {
			if value is Call && t.sum_may_return_integer_zero(value) {
				t.numeric_scalar_results[node.name] = true
			}
			array_binding := t.sum_result_array_binding(node.body, *value)
			if array_binding != '' {
				if declared := node.returns {
					if t.typename_from_annotation(*declared) == '[]f64' {
						t.sum_array_binding = array_binding
						t.sum_array_results[node.name] = true
						t.sum_uniform_array_results[node.name] = t.sum_result_array_is_uniform(node.body, array_binding)
					}
				}
			}
		}
		t.sum_list_kinds = parameter_proofs
	}
	if !node.is_void && !node.is_generator && node.name != '__init__' {
		if t.recursive_int_results[node.name] && !node.is_class_method && !node.is_nested {
			t.current_return_type = 'int'
			signature << 'int'
			t.func_return_types[node.name] = 'int'
		} else if t.numeric_scalar_results[node.name] && !node.is_class_method && !node.is_nested {
			t.current_return_type = 'Py2vNumber'
			signature << t.current_return_type
			t.func_return_types[node.name] = t.current_return_type
		} else if ret := node.returns {
			ret_type := if (t.numeric_array_results[node.name] || t.sum_array_results[node.name])
				&& !node.is_class_method {
				'[]Py2vNumber'
			} else {
				v_return_type(t.typename_from_annotation(*ret))
			}
			t.current_return_type = ret_type
			if ret_type.starts_with('(') {
				t.current_return_count = ret_type.count(',') + 1
			}
			signature << ret_type
			t.func_return_types[node.name] = ret_type
		} else if node.v_annotation != '' {
			// Use inferred return type from frontend analysis
			mut ret_type := t.map_type(node.v_annotation)
			if ret_type == 'auto' {
				ret_type = 'Any'
			}
			signature << ret_type
			t.func_return_types[node.name] = ret_type
		} else {
			// Fallback to Any if no type information available
			inferred := 'Any'
			signature << inferred
			t.func_return_types[node.name] = inferred
		}
	}

	// A nested definition's signature belongs to this lexical scope. Keep the
	// current function's metadata, and discard metadata introduced by its body.
	saved_nested_defaults := t.func_defaults.clone()
	saved_nested_counts := t.func_param_count.clone()
	saved_nested_params := t.func_param_types.clone()
	saved_nested_returns := t.func_return_types.clone()
	saved_nested_mut := t.mut_param_indices.clone()
	saved_nested_generators := t.generator_signatures.clone()
	defer {
		t.func_defaults = saved_nested_defaults
		t.func_param_count = saved_nested_counts
		t.func_param_types = saved_nested_params
		t.func_return_types = saved_nested_returns
		t.mut_param_indices = saved_nested_mut
		t.generator_signatures = saved_nested_generators
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
				if stmt.is_nested || nl_names.len > 0 {
					// Emit as an inline closure variable with a mut capture list.
					body_stmts << Stmt(stmt)
				} else {
					nested_fndefs << t.visit_function_def(stmt)
				}
			}
			AsyncFunctionDef {
				if stmt.is_nested {
					body_stmts << Stmt(stmt)
				} else {
					nested_fndefs << t.visit_async_function_def(stmt)
				}
			}
			else {
				body_stmts << stmt
			}
		}
	}

	// A nested `def` may sit inside a block (if/for/try/with). V only allows
	// `fn` declarations at the top level of a function body, so lift any that are
	// nested deeper and emit them alongside the others.
	body_stmts = t.hoist_block_fns(body_stmts, mut nested_fndefs, false)

	// Pre-scan body for variables passed to mut-parameter functions
	t.prescan_mut_call_args(body_stmts)
	mut condition_parameters := node.args.args.clone()
	condition_parameters << node.args.posonlyargs
	condition_parameters << node.args.kwonlyargs
	if vararg := node.args.vararg { condition_parameters << vararg }
	if kwarg := node.args.kwarg { condition_parameters << kwarg }
	t.prepare_condition_walruses(node.condition_walrus_names, condition_parameters)

	// Build body
	mut body_lines := []string{}
	if node.is_generator {
		body_lines << t.indent_code('defer { ch.close() }', 1)
	}
	if param_copies.len > 0 {
		body_lines << t.indent_code(param_copies.join('\n'), 1)
	}
	body_lines << t.visit_body_stmts(body_stmts, 1)
	if node.dunder_op.starts_with('py2v_overload_') {
		body_lines << "\tpanic('typing.overload stub is not callable')"
	}
	condition_declarations := t.condition_walrus_declarations()
	if condition_declarations != '' {
		body_lines.prepend(t.indent_code(condition_declarations, 1))
	}
	body := body_lines.join('\n')

	mut func_code := '${dunder_comment}${signature.join(' ')} {\n${body}\n}'
	if node.raises {
		// Keep the original signature for indirect and external callers.
		params := '${emit_name}${generic_list}(${args_strs.join(', ')})'
		at := signature.index(params)
		if at >= 0 {
			head := signature[..at].join(' ')
			ret := signature[at + 1..].join(' ')
			mut forwarded := []string{}
			for arg in args_strs {
				words := arg.split(' ')
				forwarded << if words[0] == 'mut' && words.len > 1 {
					'mut ${words[1]}'
				} else {
					words[0]
				}
			}
			failure := if t.native_exceptions.len == 0 {
				'pyrt.fail(err)'
			} else {
				t.report_uncaught_error('err')
			}
			receiver := if node.is_class_method { 'self.' } else { '' }
			call := '${receiver}${emit_name}_py(${forwarded.join(', ')}) or { ${failure} }'
			wrapper_body := if ret == '' { call } else { 'return ${call}' }
			wrapper := '${head} ${params} ${ret} {\n\t${wrapper_body}\n}'
			func_code = '${dunder_comment}${head} ${emit_name}_py${generic_list}(${args_strs.join(', ')}) !${ret} {\n${body}\n}'
			if t.emit_pub || node.is_class_method {
				func_code += '\n\n' + wrapper
			} else {
				t.result_wrappers[emit_name] = wrapper
			}
		}
	}

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
	t.sum_list_kinds = saved_sum_list_kinds.clone()
	t.escaped_identifiers = saved_escaped_identifiers.clone()
	t.local_idents = saved_local_idents.clone()
	t.init_import_aliases = saved_init_aliases.clone()
	t.init_capture_locals = saved_init_captures.clone()
	t.current_classmethod = saved_classmethod

	// A nested function must not inherit the enclosing function's return arity.
	t.current_return_count = saved_return_count
	t.current_return_type = saved_return_type
	if nested_fndefs.len > 0 {
		t.current_class_name = saved_current_class
		t.scope_idents = saved_scope_idents
		t.param_idents = saved_param_idents
		return nested_fndefs.join('\n') + '\n' + notes_prefix + decorator_comments.join('\n') + if decorator_comments.len > 0 {
			'\n'
		} else {
			''
		} + func_code
	}
	t.current_class_name = saved_current_class
	t.scope_idents = saved_scope_idents
	t.param_idents = saved_param_idents
	return notes_prefix + decorator_comments.join('\n') + if decorator_comments.len > 0 {
		'\n'
	} else {
		''
	} + func_code
}

// visit_async_function_def emits V code for an AsyncFunctionDef node (converted to sync).
pub fn (mut t VTranspiler) visit_async_function_def(node AsyncFunctionDef) string {
	// Convert to regular FunctionDef
	returns := if r := node.returns {
		&r
	} else {
		none
	}
	fd := FunctionDef{
		is_nested:              node.is_nested
		is_recursive:           node.is_recursive
		capture_names:          node.capture_names
		capture_mutable:        node.capture_mutable
		capture_refusal:        node.capture_refusal
		capture_types:          node.capture_types
		name:                   node.name
		args:                   node.args
		body:                   node.body
		decorator_list:         node.decorator_list
		returns:                returns
		type_comment:           node.type_comment
		loc:                    node.loc
		is_generator:           node.is_generator
		is_void:                node.is_void
		mutable_vars:           node.mutable_vars
		is_class_method:        node.is_class_method
		class_name:             node.class_name
		decorator_kind:         node.decorator_kind
		dunder_op:              node.dunder_op
		condition_walrus_names: node.condition_walrus_names
		v_annotation:           if node.condition_walrus_names.len > 0 {
			node.v_annotation
		} else {
			''
		}
	}
	return t.visit_function_def_or_closure(fd)
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
			// A V interface cannot require an operator, and a name that starts with an
			// underscore is no method name: a protocol's `__lt__` and its kin are left out.
			if fd.name.starts_with('__') && fd.name.ends_with('__') {
				continue
			}
			// Build interface method signature (no body)
			mut args_strs := []string{}
			for arg in fd.args.args {
				if arg.arg == 'self' {
					continue
				}
				mut typename := 'Any'
				if ann := arg.annotation {
					typename = t.typename_from_annotation(*ann)
					if typename == '' {
						typename = 'Any'
					}
				}
				args_strs << '${escape_local_decl(arg.arg)} ${typename}'
			}
			mut ret_type := ''
			if !fd.is_void {
				if ret := fd.returns {
					ret_type = t.typename_from_annotation(*ret)
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
	t.init_import_aliases.delete(node.name)
	emitted_name := t.local_class_name(node.name)
	if node.bases.len == 1 && native_enum_base(node.bases[0]) {
		return t.visit_nominal_enum(node, emitted_name)
	}

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
	module_names := if t.emit_pub { t.module_idents.values() } else { []string{} }

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
						class_name := t.registry.class_names['${t.current_dotted}.${node.name}'] or { node.name }
						symbol := class_attr_symbol_name(class_name, attr_name)
						// A package can export Status.VALID under STATUS_VALID.
						// Keep the generated storage distinct from that alias.
						class_attr_syms[attr_name] = if symbol in module_names {
							t.registry.helper_name(t.module_name, 'class_${symbol}_', t.source_words)
						} else {
							symbol
						}
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
		mut field_annotations := map[string]Expr{}
		for stmt in node.body {
			if stmt is AnnAssign && stmt.target is Name && t.has_class_annotation(stmt.annotation) {
				field_annotations[(stmt.target as Name).id] = stmt.annotation
			}
		}
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
			}
			if !has_typed_fields {
				fields << 'pub mut:'
				has_typed_fields = true
			}
			mut typ := if annotation := field_annotations[decl] {
				t.typename_from_annotation(annotation)
			} else {
				t.map_type(decl_type)
			}
			if typ == 'auto' {
				typ = 'Any'
			}
			if typ !in node.type_params && should_emit_ref_field_type(typ) {
				typ = '&${typ}'
			}
			if typ == 'u64' && decl_type != 'c_uint64' {
				t.wide_members['field:${emitted_name}.${decl}'] = true
			}
			if default_expr := node.class_defaults[decl] {
				// Struct field defaults are evaluated outside the Python module's
				// executable initialization. A module-local wide constant, a
				// computed mask, or a call is not visible there merely because
				// the field has type u64. Refuse rather than emitting an
				// unbound V identifier or bypassing the wide-use check.
				default_str := if typ == 'u64' && default_expr !is Constant
					&& (t.has_u64_bits(default_expr) || t.has_wide_destination(default_expr)) {
					t.refuse_wide('u64 class field default needs a compile-time constant')
				} else if typ == 'u64' {
					t.visit_integer_boundary(default_expr, .scalar_storage, typ)
				} else {
					t.visit_expr(default_expr)
				}
				fields << t.indent_code('${field_name} ${typ} = ${default_str}', 1)
			} else if typ.starts_with('&pyrt.ListRef[') {
				t.add_using('pyrt')
				fields << t.indent_code('${field_name} ${typ} = ${typ}{}', 1)
			} else {
				fields << t.indent_code('${field_name} ${typ}', 1)
			}
			field_names << field_name
		}
	}
	for base in node.bases {
		path := expr_class_path(base)
		if name := t.renamed_class(path) {
			base_fields := t.registry.class_fields_by_path[path]
			t.known_classes[name] = base_fields
			t.class_direct_fields[name] = base_fields
			base_names << name
		} else if base is Name {
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

	// Embed base classes (inheritance -> struct embedding).
	//
	// Only bases that resolve to a class in this project are embedded. Python
	// lets an exception mix in a builtin such as `class E(KeyError, Base)`, and
	// V has no `KeyError` to embed, so the base is dropped here rather than
	// becoming a reference to a type that does not exist.
	mut embeds := []string{}
	mut embeddable_bases := []string{}
	for base_name in base_names {
		if base_name in t.known_classes {
			embeds << t.indent_code(emitted_class_name(base_name), 1)
			embeddable_bases << base_name
		}
	}
	t.class_base_names[node.name] = embeddable_bases

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
					ret_type := t.typename_from_annotation(*ret)
					if ret_type.len > 0 {
						t.func_return_types[stmt.name] = ret_type
					}
					if ret_type == 'u64' && ret is Name && ret.id == 'u64' {
						t.wide_members['method:${emitted_name}.${stmt.name}'] = true
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
	init_method := init_method_name(node)
	mut methods := []string{}
	mut static_fns := []string{}
	for stmt in node.body {
		match stmt {
			FunctionDef {
				// Mark as class method
				mut fd := stmt
				fd.is_class_method = true
				fd.class_name = node.name
				if fd.name == '__init__' && fd.dunder_op == '' {
					fd.dunder_op = init_method
				}
				// The method emitter handles ordinary parameters; preserve the
				// initializer's positional-only parameters in that signature too.
				if fd.name == '__init__' && fd.args.posonlyargs.len > 0 {
					mut parameters := fd.args.posonlyargs.clone()
					parameters << fd.args.args
					fd.args = Arguments{ ...fd.args, args: parameters, posonlyargs: []Arg{} }
				}
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
	if constructor := t.local_init_constructors[node.name] {
		factory := t.emit_init_factory(constructor)
		if factory != '' {
			result += '\n\n' + factory
		}
	}
	return result
}

// visit_assign emits V code for an Assign statement.
pub fn (mut t VTranspiler) visit_assign(node Assign) string {
	return t.visit_assignment(node, false)
}

fn (mut t VTranspiler) visit_assignment(node Assign, package_initializer bool) string {
	saved_updates := t.integer_update_names
	t.integer_update_names = []
	if t.loop_breaks.len > 0 {
		for target in node.targets {
			for name in growth_targets(target) {
				t.integer_update_names << name
				t.integer_update_names << t.loop_breaks.last().copy_targets[name]
			}
		}
	}
	defer { t.integer_update_names = saved_updates }
	if node.targets.len == 1 && node.targets[0] is Name {
		name := (node.targets[0] as Name).id
		if !(node.targets[0] as Name).is_mutable && !t.extra_mut_vars[name] {
			t.note_sum_source(name, node.value)
		} else {
			t.sum_list_kinds.delete(name)
		}
		// Aliases can mutate the original Python list through another name.
		if node.value is Name {
			t.sum_list_kinds.delete(node.value.id)
		}
	}
	// Record what this assignment binds, so a later `for` over the same Python
	// name is given a fresh V variable instead of shadowing it. Whether a name
	// was already bound has to be sampled before this statement binds anything,
	// or a first declaration would look like a rebind of itself.
	mut was_bound := map[string]bool{}
	for target in node.targets {
		for name in for_target_names(target) {
			was_bound[name] = t.is_bound_in_scope(name)
		}
	}
	for target in node.targets {
		for name in for_target_names(target) {
			t.note_scope_binding(name)
		}
	}
	if node.targets.len == 1 {
		target := node.targets[0]
		if target is Name || target is Attribute {
			rebind := target is Attribute || (target is Name
				&& (was_bound[target.id] || t.global_vars[target.id]
					|| target.id in node.redefined_targets))
			stores_word := if target is Name {
				t.var_types[target.id] == 'u64'
			} else {
				t.has_u64_bits(target)
			}
			if stores_word || (!rebind && t.has_u64_bits(node.value))
				|| (rebind && target is Name && t.condition_walrus_vars[target.id]
					&& t.condition_walrus_types[target.id] == 'u64') {
				dest := t.visit_expr_at(target, .scalar_storage, 'u64')
				value := t.visit_integer_boundary(node.value, .scalar_storage, 'u64')
				if target is Name {
					t.var_types[target.id] = 'u64'
				}
				if rebind {
					return '${dest} = ${value}'
				}
				kw := if target is Name && (target.is_mutable || t.extra_mut_vars[target.id]) {
					'mut '
				} else {
					''
				}
				return '${kw}${dest} := ${value}'
			}
			if target is Name && (t.has_large_integer(target)
				|| (!rebind && t.has_large_integer(node.value))) {
				dest := t.visit_expr(target)
				value := if t.has_large_integer(node.value) {
					t.visit_expr_at(node.value, .scalar_storage, large_integer_type)
				} else {
					t.refuse_wide('assignment changes the representation of an exact large integer')
				}
				t.var_types[target.id] = large_integer_type
				if rebind {
					return '${dest} = ${value}'
				}
				kw := if target.is_mutable || t.extra_mut_vars[target.id] { 'mut ' } else { '' }
				return '${kw}${dest} := ${value}'
			}
			if target is Name {
				value := *node.value
				if !rebind && target.id == t.sum_array_binding {
					code := t.visit_expr(value)
					t.runtime_helper('numeric_choice')
					t.runtime_helper('float_text')
					t.var_types[target.id] = '[]Py2vNumber'
					return 'mut ${t.visit_expr(target)} := ${as_receiver(code)}.map(Py2vNumber(it))'
				}
				if t.var_types[target.id] == 'Py2vNumber'
					|| (!rebind && target.is_mutable && value is Call && value.func is Name
						&& t.recursive_int_results[value.func.id]) {
					code := t.numeric_choice_value(value, t.visit_expr(value))
					dest := t.visit_expr(target)
					t.var_types[target.id] = 'Py2vNumber'
					return if rebind { '${dest} = ${code}' } else { 'mut ${dest} := ${code}' }
				}
			}
		}
	}
	for target in node.targets {
		if t.has_wide_destination(target) {
			return t.refuse_wide('unsigned storage requires a single scalar assignment')
		}
	}
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
							'Any'
						}
						return '${tname} := map[string]${val_type}{}'
					}
					'Counter' {
						// A user class of the same name shadows collections.Counter,
						// which is reached in Python as `collections.Counter(...)`.
						if fname !in t.known_classes {
							// Counter(iterable) → build map[string]int from counts
							if call.args.len > 0 {
								iter := t.visit_expr(call.args[0])
								return '${tname} := (fn (items []string) map[string]int {\n\tmut m := map[string]int{}\n\tfor item in items { m[item]++ }\n\treturn m\n})(${iter})'
							}
							return '${tname} := map[string]int{}'
						}
					}
					'deque' {
						// deque(list) → []Any (V arrays support append/prepend)
						if call.args.len > 0 {
							inner := t.visit_expr(call.args[0])
							return 'mut ${tname} := []Any(${inner})'
						}
						return 'mut ${tname} := []Any{}'
					}
					'OrderedDict' {
						// OrderedDict() → map[string]Any{} (V maps are insertion-ordered)
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
				previous := t.var_types[n.id] or { '' }
				// A rebinding does not change the declared type of a native Any map.
				if !(n.id in node.redefined_targets && previous.starts_with('map[')
					&& previous.ends_with(']Any')) {
					t.var_types[n.id] = inferred
				}
			}
		}
	}

	mut assigns := []string{}
	use_temp := node.targets.len > 1 && node.value is Call
	assignment_temp := if use_temp { t.new_tmp('assignment') } else { '' }

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
		assigns << 'mut ${assignment_temp} := ${t.visit_expr(node.value)}'
	}

	for target in node.targets {
		mut is_redefined := false
		if target is Name {
			n := target as Name
			is_redefined = n.id in node.redefined_targets || (t.global_vars[n.id] or { false })
			// Rebinding a name that is already a parameter or local of this
			// function is a reassignment, not a new declaration. V rejects
			// `x := ...` when `x` is already in scope, and a Python rebinding of
			// the same name is the same variable.
			if !is_redefined && was_bound[n.id] {
				is_redefined = true
				if !t.condition_walrus_vars[n.id] {
					t.extra_mut_vars[n.id] = true
				}
			}
		}

		value_str := if use_temp {
			assignment_temp
		} else if package_initializer && node.value is ListComp {
			t.module_string_product(node.value) or { t.visit_expr(node.value) }
		} else {
			t.visit_expr(node.value)
		}

		if target is Name && node.value is ListComp && value_str.contains('pyrt.new_tuple(') {
			// The generated element is a boxed Python tuple, not a plain V array.
			t.var_types[(target as Name).id] = '[]pyrt.Value'
		}
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
					is_multi_return := node.value is Call
						&& get_expr_annotation(node.value).starts_with('(')

					if is_tuple_swap || is_multi_return {
						// Direct tuple swap: x, y = y, x or a, b, c = 1, 2, 3
						mut subtargets := []string{}
						mut any_redefined := elts.len > 0 && elts.all(it is Name && was_bound[it.id])
						mut has_subscript_or_attr := false

						// Check if all targets are mutable names (meaning they were defined earlier)
						for st in elts {
							if st is Name {
								if st.id in node.redefined_targets {
									any_redefined = true
								}
							} else if st is Subscript || st is Attribute {
								has_subscript_or_attr = true
							}
						}

						// Mutability alone does not make the first assignment a rebinding.
						for st in elts {
							mut subkw := ''
							if st is Name {
								if !any_redefined && !has_subscript_or_attr {
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
						op := if is_redefined || any_redefined
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
							op := if any_redefined || t.visit_expr(st) == '_' { '=' } else { ':=' }
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
							op := if any_redefined || t.visit_expr(st) == '_' { '=' } else { ':=' }
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

	code := assigns.join('\n')
	for target in node.targets {
		if target is Name && (t.local_idents[target.id] or { '' }).starts_with('(*') {
			return 'unsafe {\n${t.indent_code(code, 1)}\n}'
		}
	}
	return code
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

// modulo_expression uses Python's divisor-signed remainder for native numbers.
// Dynamic values and overloaded operators keep their runtime/operator dispatch.
fn (mut t VTranspiler) modulo_expression(left Expr, right Expr, a string, b string, loc Location) string {
	la := t.infer_expr_type(left)
	ra := t.infer_expr_type(right)
	if la in ['Any', 'pyrt.Value'] || ra in ['Any', 'pyrt.Value'] {
		t.add_using('pyrt')
		return 'pyrt.modulo(pyrt.box(${a}), pyrt.box(${b}))'
	}
	if la in ['f64', 'float', 'f32'] || ra in ['f64', 'float', 'f32'] {
		t.add_using('math')
		return '${t.runtime_helper('float_mod')}(f64(${a}), f64(${b}))'
	}
	if code := t.native_integer_binary('Mod', left, right, a, b, loc, false) {
		return code
	}
	if (is_v_int_type(la) || la == 'bool') && (is_v_int_type(ra) || ra == 'bool') {
		t.add_using('math')
		lhs := if la == 'bool' { 'int(${a})' } else { a }
		rhs := if ra == 'bool' { 'int(${b})' } else { b }
		// Pin the operand type so V's result context cannot infer a different one.
		instance := if la in ['int', 'bool'] && ra in ['int', 'bool'] { '[int]' } else { '' }
		return 'math.modulo_floored${instance}(${lhs}, ${rhs})'
	}
	if la == '' || ra == '' || generic_letters(la).len > 0 || generic_letters(ra).len > 0 {
		t.add_using('math')
		t.runtime_helper('integer_mod')
		return '${t.runtime_helper('generic_mod')}(${a}, ${b}, ${t.integer_site(loc)})'
	}
	return '${paren_left(a, 5)} % ${paren_right(b, 5)}'
}

// captured_aug_assign captures a subscript's container and index, or an attribute's receiver,
// before reading the old value and evaluating the right operand. The store reuses them.
fn (mut t VTranspiler) captured_aug_assign(node AugAssign, op_type string) string {
	mut lines := []string{}
	mut target := t.visit_expr(*node.target)
	if node.target is Subscript {
		sub := node.target as Subscript
		if sub.slice is Slice || sub.slice is Tuple {
			return 'py2v_unsupported_modulo_assignment_target()'
		}
		container := t.new_tmp('container')
		index := t.new_tmp('index')
		if op_type == 'Mod' && t.infer_expr_type(*sub.value) in ['Any', 'pyrt.Value'] {
			t.add_using('pyrt')
			old := t.new_tmp('old')
			lines << '${container} := pyrt.box(${t.visit_expr(*sub.value)})'
			lines << '${index} := pyrt.box(${t.visit_expr(*sub.slice)})'
			lines << '${old} := pyrt.item_at(${container}, ${index})'
			lines << 'pyrt.set_index(${container}, ${index}, pyrt.modulo(${old}, pyrt.box(${t.visit_expr(node.value)})))'
			return lines.join('\n')
		}
		if owner := t.augmented_list_owner(*sub.value) {
			// Capture the descriptor before the index or RHS can replace its slot.
			selected := t.new_tmp('list')
			lines << 'mut ${selected} := unsafe { ${t.visit_expr(owner)} }'
			lines << 'mut ${container} := &${selected}.items'
		} else {
			lines << 'mut ${container} := &(${t.visit_expr(*sub.value)})'
		}
		lines << '${index} := ${t.visit_expr(*sub.slice)}'
		// Negative indices are interpreted afresh at the store, as in Python.
		if t.infer_expr_type(*sub.value).starts_with('[]') {
			target = '(*${container})[if ${index} < 0 { ${container}.len + ${index} } else { ${index} }]'
		} else {
			target = '(*${container})[${index}]'
		}
	} else if node.target is Attribute {
		attr := node.target as Attribute
		receiver := t.new_tmp('receiver')
		if op_type == 'Mod' && t.infer_expr_type(*attr.value) in ['Any', 'pyrt.Value'] {
			t.add_using('pyrt')
			old := t.new_tmp('old')
			lines << '${receiver} := pyrt.box(${t.visit_expr(*attr.value)})'
			lines << "${old} := pyrt.getattr(${receiver}, '${attr.attr}') or { pyrt.fail(err) }"
			lines << "pyrt.setattr(${receiver}, '${attr.attr}', pyrt.modulo(${old}, pyrt.box(${t.visit_expr(node.value)}))) or { pyrt.fail(err) }"
			return lines.join('\n')
		}
		lines << 'mut ${receiver} := &(${t.visit_expr(*attr.value)})'
		target = '${receiver}.${target.all_after_last('.')}'
	} else if node.target !is Name {
		return 'py2v_unsupported_modulo_assignment_target()'
	}
	old := t.new_tmp('old')
	shared_add := op_type == 'Add' && t.infer_expr_type(*node.target).starts_with('&pyrt.ListRef[')
	lines << '${if shared_add { 'mut ' } else { '' }}${old} := ${target}'
	value := t.visit_expr(node.value)
	if shared_add {
		lines << '${old}.items << ${value}'
		lines << '${target} = ${old}'
	} else if op_type == 'Mod' {
		result := t.new_tmp('aug_result')
		lines << '${result} := ${t.modulo_expression(*node.target, node.value, old, value, node.loc)}'
		lines << '${target} = ${result}'
	} else {
		lines << t.visit_aug_assign_once(node, op_type, target, value, old)
	}
	code := lines.join('\n')
	if node.target is Name && target.starts_with('(*') {
		return 'unsafe {\n${t.indent_code(code, 1)}\n}'
	}
	return code
}

// augmented_list_owner finds the stable reference behind a shared list's items.
fn (mut t VTranspiler) augmented_list_owner(container Expr) ?Expr {
	if container is Attribute && container.attr == 'items'
		&& t.infer_expr_type(*container.value).starts_with('&pyrt.ListRef[') {
		return *container.value
	}
	return none
}

// visit_aug_assign emits V code for an AugAssign statement.
pub fn (mut t VTranspiler) visit_aug_assign(node AugAssign) string {
	if t.has_u64_bits(node.target) || t.has_u64_bits(node.value) {
		return t.refuse_wide('augmented assignment of an unsigned word is unsupported')
	}
	op_type := get_op_type(node.op)
	if t.proven_counter_step != '' && t.proven_counter_step == node.loc.str() {
		return '${t.visit_expr(*node.target)} += 1'
	}
	left_type := t.infer_expr_type(*node.target)
	right_type := t.infer_expr_type(node.value)
	native := op_type in ['Add', 'Sub', 'Mult', 'FloorDiv', 'Pow', 'LShift', 'RShift']
		&& (native_integer_type(left_type) || native_integer_type(right_type))
		&& may_use_native_integer(left_type) && may_use_native_integer(right_type)
	target_expr := *node.target
	rhs_can_run_code := !t.runs_no_code(node.value)
	// A direct field or plain index needs no temporary pointer when the RHS
	// cannot change which receiver or index the store addresses.
	capture_target := match target_expr {
		Name { rhs_can_run_code }
		Subscript {
			(target_expr.value is Name || t.augmented_list_owner(*target_expr.value) != none)
				&& (rhs_can_run_code || has_computed_index(target_expr))
		}
		Attribute { target_expr.value is Name && rhs_can_run_code }
		else { false }
	}
	if native && capture_target {
		return t.captured_aug_assign(node, op_type)
	}
	if op_type == 'Mod' || (op_type in ['Pow', 'FloorDiv'] && has_list_reference(*node.target))
		|| (op_type == 'Add' && t.infer_expr_type(*node.target).starts_with('&pyrt.ListRef[')) {
		return t.captured_aug_assign(node, op_type)
	}
	// `**=` and `//=` become `target = f(target, val)`, which names the target twice. Python
	// evaluates the target's indices once, in the order they are written, before the
	// right-hand side. So when an index or slice bound is computed (`x[f()] **= 2`) or the
	// right-hand side could run code (`x[i] **= g()`), every index and bound of a target that
	// starts from a name is computed into a temp first, in that order: a name too, since a
	// later call could change it, and a negative literal as `x.len - n`, since a later call
	// could change the length. Non-negative literals stay inline. Reading the containers the
	// indices select (`grid[i]` in `grid[f()][g()]`) still comes after all of them.
	mut prelude := []string{}
	target_node := if (native || op_type in ['Pow', 'FloorDiv']) && can_hoist_indices(*node.target)
		&& (has_computed_index(*node.target) || rhs_can_run_code) {
		t.index_once(*node.target, mut prelude)
	} else {
		*node.target
	}
	target := t.visit_expr(target_node)
	val := t.visit_expr(node.value)
	mut old := target
	if native && rhs_can_run_code {
		old = t.new_tmp('old')
		prelude << '${old} := ${target}'
	}
	mut code := t.visit_aug_assign_once(node, op_type, target, val, old)
	if node.target is Name && target.starts_with('(*') {
		code = 'unsafe {\n${t.indent_code(code, 1)}\n}'
	}
	if prelude.len > 0 {
		return prelude.join('\n') + '\n' + code
	}
	return code
}

// has_list_reference finds shared descriptors underneath a target expression.
fn has_list_reference(target Expr) bool {
	if get_expr_annotation(target).contains('pyrt.ListRef[') { return true }
	return match target {
		Subscript { has_list_reference(*target.value) }
		Attribute { has_list_reference(*target.value) }
		else { false }
	}
}

// can_hoist_indices reports whether the subscripts and attributes of `target` start from a
// name, with no slice step and no slice inside a tuple subscript. A call on the way cannot
// move into a temp, and neither of those slices is emitted faithfully, so such a target is
// left as it is.
fn can_hoist_indices(target Expr) bool {
	return match target {
		Name { true }
		Subscript { !blocks_hoisting(*target.slice) && can_hoist_indices(*target.value) }
		Attribute { can_hoist_indices(*target.value) }
		else { false }
	}
}

// blocks_hoisting reports a slice with a step, or a tuple subscript holding a slice
// (`a[i:j, k]`).
fn blocks_hoisting(e Expr) bool {
	return match e {
		Slice { e.step != none }
		Tuple { e.elts.any(it is Slice) }
		else { false }
	}
}

// has_computed_index reports whether some index or slice bound of `target` is neither a
// name nor a literal.
fn has_computed_index(target Expr) bool {
	return match target {
		Subscript {
			slice := *target.slice
			here := if slice is Slice {
				!bound_is_plain(slice.lower) || !bound_is_plain(slice.upper)
			} else {
				!is_plain_index(slice)
			}
			here || has_computed_index(*target.value)
		}
		Attribute {
			has_computed_index(*target.value)
		}
		else {
			false
		}
	}
}

fn bound_is_plain(bound ?&Expr) bool {
	if b := bound {
		return is_plain_index(*b)
	}
	return true
}

// runs_no_code reports whether evaluating `e` cannot run code: a name, a literal, or an
// operator on numbers, booleans or strings. An operator on anything else can call an
// overload such as `__add__`.
fn (mut t VTranspiler) runs_no_code(e Expr) bool {
	return match e {
		Name, Constant {
			true
		}
		UnaryOp {
			t.has_builtin_type(*e.operand) && t.runs_no_code(*e.operand)
		}
		BinOp {
			t.has_builtin_type(*e.left) && t.has_builtin_type(*e.right)
				&& t.runs_no_code(*e.left) && t.runs_no_code(*e.right)
		}
		else {
			false
		}
	}
}

fn (mut t VTranspiler) has_builtin_type(e Expr) bool {
	return t.infer_expr_type(e) in ['int', 'i8', 'i16', 'i64', 'u8', 'u16', 'u32', 'u64', 'f32',
		'f64', 'bool', 'string']
}

// index_once returns `target` with every subscript index and slice bound that is not a
// non-negative literal replaced by a temp, and appends each temp's declaration to `prelude`
// in the order they are written. A negative literal in the subscript stored into is kept:
// Python applies it again at the store (`x[-1] **= f()` stores into the last element after
// f runs), while one in a container on the way is applied once, when that container is read.
fn (mut t VTranspiler) index_once(target Expr, mut prelude []string) Expr {
	return t.index_once_at(target, true, mut prelude)
}

fn (mut t VTranspiler) index_once_at(target Expr, stored bool, mut prelude []string) Expr {
	match target {
		Subscript {
			value := t.index_once_at(*target.value, false, mut prelude)
			mut slice := *target.slice
			if slice is Slice {
				slice = Expr(t.bounds_once(slice, value, mut prelude))
			} else if slice !is Constant && !(stored && negative_literal(slice) != none) {
				slice = t.hoist_index(slice, value, target.loc, mut prelude)
			}
			return Expr(Subscript{
				...target
				value: &value
				slice: &slice
			})
		}
		Attribute {
			value := t.index_once_at(*target.value, false, mut prelude)
			return Expr(Attribute{
				...target
				value: &value
			})
		}
		else {
			return target
		}
	}
}

// bounds_once returns `s` with each bound that is not a non-negative literal replaced by a
// temp, the lower bound first, as Python evaluates them. Python applies the slice after
// both bounds, so a negative literal bound counts from the end of the container as it is
// then (`rows[-1:grow()]` sees the row `grow` appends): its `len - n` comes last.
fn (mut t VTranspiler) bounds_once(s Slice, container Expr, mut prelude []string) Slice {
	mut out := s
	if lower := s.lower {
		if *lower !is Constant && negative_literal(*lower) == none {
			name := t.hoist_index(*lower, container, s.loc, mut prelude)
			out.lower = &name
		}
	}
	if upper := s.upper {
		if *upper !is Constant && negative_literal(*upper) == none {
			name := t.hoist_index(*upper, container, s.loc, mut prelude)
			out.upper = &name
		}
	}
	if lower := s.lower {
		if negative_literal(*lower) != none {
			name := t.hoist_index(*lower, container, s.loc, mut prelude)
			out.lower = &name
		}
	}
	if upper := s.upper {
		if negative_literal(*upper) != none {
			name := t.hoist_index(*upper, container, s.loc, mut prelude)
			out.upper = &name
		}
	}
	return out
}

// hoist_index declares a temp holding the index `e` of `container` in `prelude` and returns
// the temp's name. A negative literal becomes `container.len - n`, as visit_subscript
// writes it, so the length is read here rather than at the store.
fn (mut t VTranspiler) hoist_index(e Expr, container Expr, loc Location, mut prelude []string) Expr {
	tmp := t.new_tmp('idx')
	value := if n := negative_literal(e) {
		'${t.visit_expr(container)}.len - ${n}'
	} else {
		t.visit_expr(e)
	}
	prelude << '${tmp} := ${value}'
	return Expr(Name{
		id:  tmp
		loc: loc
	})
}

// negative_literal returns n for an index written `-n` with an integer literal n.
fn negative_literal(e Expr) ?int {
	if e is UnaryOp && e.op is USub && e.operand is Constant {
		c := e.operand as Constant
		if c.value is int {
			return c.value as int
		}
	}
	return none
}

// is_plain_index reports whether an index can be written twice without being evaluated
// twice: a name, a literal or a negated literal (which visit_subscript turns into
// `x.len - n`).
fn is_plain_index(e Expr) bool {
	return match e {
		Name, Constant { true }
		UnaryOp { e.operand is Constant }
		else { false }
	}
}

// visit_aug_assign_once emits an augmented assignment whose target and value are already
// rendered, so that each is evaluated as written.
fn (mut t VTranspiler) visit_aug_assign_once(node AugAssign, op_type string, target string, val string, old string) string {
	if code := t.native_integer_binary(op_type, *node.target, node.value, old, val, node.loc, true) {
		if target != old {
			result := t.new_tmp('aug_result')
			return '${result} := ${code}\n${target} = ${result}'
		}
		return '${target} = ${code}'
	}
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
			return '${target} = math.floor(${old} / ${paren_right(val, 5)})'
		}
		return '${target} = math.divide_floored(${old}, ${val}).quot'
	}
	// Pow has no V operator; expand to assignment with math function
	if op_type == 'Pow' {
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
			t.add_using('math')
			return '${target} = math.pow(${old}, ${val})'
		}
		return '${target} = ${t.checked_integer('power', [old, val], node.loc)}'
	}
	// `xs += ys` on a list appends; V has no `+=` for arrays
	if op_type == 'Add' && node.target is Name {
		if (t.var_types[(node.target as Name).id] or { '' }).starts_with('[]') {
			return '${target} << ${val}'
		}
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
	if op_sym in ['+', '-', '*', '/', '%'] {
		t.note_any_operator(*node.target, node.value, old, val)
	}
	if target != old {
		prec := v_prec(op_sym)
		result := t.new_tmp('aug_result')
		return '${result} := ${paren_left(old, prec)} ${op_sym} ${paren_right(val, prec)}\n${target} = ${result}'
	}
	return '${target} ${op_sym}= ${val}'
}

// visit_ann_assign emits V code for an AnnAssign statement.
pub fn (mut t VTranspiler) visit_ann_assign(node AnnAssign) string {
	was_bound := node.target is Name && t.is_bound_in_scope(node.target.id)
	if node.target is Name {
		name := node.target.id
		if val := node.value {
			if !node.target.is_mutable && !t.extra_mut_vars[name] {
				t.note_sum_source(name, *val)
			} else {
				t.sum_list_kinds.delete(name)
			}
		} else {
			t.sum_list_kinds.delete(name)
		}
	}
	if node.target is Name { t.note_scope_binding(node.target.id) }
	type_str := t.typename_from_annotation(*node.annotation)
	target := t.visit_expr_at(node.target, .scalar_storage, type_str)

	mut kw := ''
	if node.target is Name {
		n := node.target as Name
		if n.is_mutable {
			kw = 'mut '
		}
	}

	// Attribute targets (self.x) are struct fields — use = not :=
	is_attr := node.target is Attribute
	is_condition_local := node.target is Name
		&& t.condition_walrus_vars[(node.target as Name).id]
	if is_condition_local || was_bound { kw = '' }
	op := if is_attr || is_condition_local || was_bound { '=' } else { ':=' }

	// Track variable type from annotation
	if node.target is Name && type_str != '' {
		t.var_types[(node.target as Name).id] = type_str
	}

	if val := node.value {
		if is_wide_container_type(type_str) {
			return '${kw}${target} ${op} ${t.refuse_wide('unsigned values in containers are unsupported')}'
		}
		val_str := t.visit_expr_at(val, .scalar_storage, type_str)

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
		// Populated annotated maps need their value type too: V otherwise infers it
		// from the first item, rejecting subsequent heterogeneous writes.
		if val is Dict && (val as Dict).keys.len > 0 && type_str.starts_with('map[') {
			return '${kw}${target} ${op} ${type_str}${val_str}'
		}
		// An empty dict takes the annotated key and value types
		if val is Dict && (val as Dict).keys.len == 0 && type_str.starts_with('map[')
			&& !type_str.ends_with(']') {
			return '${kw}${target} ${op} ${type_str}{}'
		}
		// `prev: Node | None = None` and `name: str | None = None` declare an optional:
		// a bare `none` has no type a value could later be assigned to.
		if !is_attr && !is_condition_local && val_str == 'none' && type_str.starts_with('?') {
			return '${kw}${target} ${op} ${type_str}(none)'
		}

		return '${kw}${target} ${op} ${t.integer_boundary(val, val_str, type_str)}'
	}

	// A bare `name: type` declares the local, so a later `for name in ...`
	// rebinds it instead of declaring it again.
	if node.target is Name {
		t.note_scope_binding((node.target as Name).id)
	}
	return '${kw}${target} ${op} ${t.zero_value_for(type_str)}'
}

// is_value_param tells whether a parameter is annotated as a Python number, string or
// bool, which py2v passes by value even when the function binds the name again.
fn is_value_param(arg Arg) bool {
	if !arg.is_mutable { return true }
	ann := arg.annotation or { return false }
	expr := *ann
	if expr is Name {
		return expr.id in ['int', 'float', 'str', 'bool'] || expr.id.starts_with('&pyrt.ListRef[')
	}
	return false
}

// any_operators are the arithmetic and ordering operators of a value of unknown type. An
// operator cannot return a result, so a Python exception raised inside one stops the
// program with its message.
const any_operators = 'fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}'

// note_any_operator records a native infix emission whose operand uses the Value alias.
fn (mut t VTranspiler) note_any_operator(left Expr, right Expr, a string, b string) {
	if t.uses_any_operators {
		return
	}
	t.uses_any_operators = a.starts_with('Any(') || b.starts_with('Any(')
		|| t.is_any_operand(left) || t.is_any_operand(right)
}

// is_any_operand recognizes Value storage, including parameters omitted from var_types.
fn (mut t VTranspiler) is_any_operand(expr Expr) bool {
	inferred := t.infer_expr_type(expr)
	annotation := get_v_annotation(expr)
	// A scalar inference can hide the Any storage of an unannotated read.
	if !t.emit_pub && annotation == '' && (expr is Name || expr is Subscript) {
		return true
	}
	if inferred == 'Any' || (t.emit_pub && inferred == 'pyrt.Value') {
		return true
	}
	if inferred != '' {
		return false
	}
	// Imported bindings and runtime call results can be opaque while emitting a package.
	return annotation == 'Any' || (t.emit_pub && annotation in ['', 'pyrt.Value'])
		|| (expr is Name && t.any_parameter_names[expr.id])
}

// mentions_word tells whether `word` stands in `code` as a whole identifier.
fn mentions_word(code string, word string) bool {
	mut from := 0
	for {
		i := code.index_after(word, from) or { return false }
		before := if i > 0 { code[i - 1] } else { u8(` `) }
		end := i + word.len
		after := if end < code.len { code[end] } else { u8(` `) }
		qualified := before == `.` && !(i >= 3 && code[i - 3..i] == '...')
		if !qualified && !(before.is_letter() || before.is_digit() || before == `_`)
			&& !(after.is_letter() || after.is_digit() || after == `_`) {
			return true
		}
		from = end
	}
	return false
}

// mentions_result_wrapper ignores literal text before the first interpolation.
// An interpolation can still contain a call or a function value.
fn mentions_result_wrapper(code string, name string) bool {
	mut start := 0
	mut i := 0
	for i < code.len {
		quote := code[i]
		if quote != `'` && quote != `"` && quote != `\`` {
			i++
			continue
		}
		end := skip_v_string(code, i)
		literal := code[i..end]
		if literal.len >= 2 && literal[literal.len - 1] == quote
			&& !literal.contains_any('\\\n') {
			if mentions_word(code[start..i], name) {
				return true
			}
			if offset := literal.index('$') {
				if mentions_word(literal[offset..], name) {
					return true
				}
			}
			start = end
		}
		i = end
	}
	return mentions_word(code[start..], name)
}

// generic_letters lists the single uppercase letters that stand as whole words in a V
// type: `T` in `T`, `[]T` and `map[string]T`, none in `Tree` or `[]Item`.
fn generic_letters(typename string) []string {
	mut letters := []string{}
	for i, c in typename {
		if c < `A` || c > `Z` {
			continue
		}
		before := if i > 0 { typename[i - 1] } else { u8(` `) }
		after := if i + 1 < typename.len { typename[i + 1] } else { u8(` `) }
		if before.is_letter() || before.is_digit() || before == `_` || before == `.`
			|| after.is_letter() || after.is_digit() || after == `_` {
			continue
		}
		letters << c.ascii_str()
	}
	return letters
}

// v_value_param_types are the V types a parameter cannot be `mut` for.
const v_value_param_types = ['int', 'i8', 'i16', 'i32', 'i64', 'u8', 'u16', 'u32', 'u64', 'f32',
	'f64', 'bool', 'string', 'rune']!

fn is_optional_value_type(typ string) bool {
	// Numeric options can coerce a supplied Python int to float or the reverse.
	return typ in ['?string', '?bool']
}

// zero_value_for returns a V zero-value expression for the named type.
pub fn (t VTranspiler) zero_value_for(typ string) string {
	if typ.starts_with('&') && typ.contains('.') {
		// a reference to a runtime object (a connection, a cursor) that is assigned before
		// it is used: its struct has reference fields and no empty form
		return '${typ}(unsafe { nil })'
	}
	return zero_value_for_type(typ)
}

// fresh_loop_ident picks a V iteration variable name that is not already bound
// by an enclosing loop, so that nesting a Python loop over the same variable
// name still compiles.
fn (t VTranspiler) fresh_loop_ident(name string, pending map[string]string) string {
	taken := pending.values()
	mut n := 0
	for {
		candidate := if n == 0 { '${name}_' } else { '${name}_${n}' }
		if candidate !in t.loop_idents && candidate !in t.scope_idents && candidate !in taken {
			return candidate
		}
		n++
	}
}

// module_const_decl turns a module-level binding that functions read into a V
// constant: a function cannot see a local of `main`. Only a one-line immutable
// declaration qualifies.
fn module_const_decl(stmt Stmt, rendered string, names []string) ?string {
	mut id := ''
	if stmt is Assign {
		if stmt.targets.len == 1 && stmt.targets[0] is Name {
			id = (stmt.targets[0] as Name).id
		}
	} else if stmt is AnnAssign {
		if stmt.target is Name {
			id = (stmt.target as Name).id
		}
	}
	if id == '' || id !in names || rendered.starts_with('mut ') {
		return none
	}
	eq := rendered.index(' := ') or { return none }
	// The declaration is the first thing rendered: a value may span lines, a
	// statement placed before it may not.
	if rendered[..eq].contains_any(' \n\t') {
		return none
	}
	return 'const ${rendered[..eq]} = ${rendered[eq + 4..]}'
}

fn contains_module_rebinding(stmt Stmt, functions map[string]string) bool {
	return match stmt {
		Assign {
			stmt.targets.len == 1 && stmt.targets[0] is Name && stmt.targets[0].id in functions
		}
		If {
			stmt.body.any(contains_module_rebinding(it, functions))
				|| stmt.orelse.any(contains_module_rebinding(it, functions))
		}
		else { false }
	}
}

// module_scope_decl renders one module-level statement as a V module-scope
// declaration.
//
// A Python module may run code at import time, and a V module cannot: there is
// no module body to run. A constant assignment becomes a `const`, which is the
// case that matters in practice — portage declares its path and error constants
// this way — and anything else is reported instead of being hidden inside a
// function that never runs.
fn module_scope_decl(stmt Stmt, rendered string, declared map[string]string) string {
	trimmed := rendered.trim_space()
	if stmt is Assign {
		assign := stmt as Assign
		if assign.targets.len == 1 && assign.targets[0] is Name {
			name := (assign.targets[0] as Name).id
			mut value := trimmed
			if eq := value.index(' := ') {
				value = value[eq + 4..]
			}
			return 'const ${declared[name] or { escape_local_decl(name) }} = ${value}'
		}
	}
	return '// TODO(py2v): module-level ${stmt_desc(stmt)} has no place in a V ' +
		'module; move it into a function and call it explicitly.'
}

// stmt_desc names a statement kind for a diagnostic comment.
fn stmt_desc(stmt Stmt) string {
	return match stmt {
		If { 'if statement' }
		For { 'for loop' }
		While { 'while loop' }
		Try { 'try block' }
		With { 'with block' }
		ExprStmt { 'expression' }
		Import { 'import' }
		ImportFrom { 'import' }
		Assert { 'assert' }
		Delete { 'delete' }
		Pass { 'pass' }
		else { 'statement' }
	}
}

// for_target_is_mutable reports whether the frontend marked `name`, one of
// the names a for-loop target binds, as a local that is assigned again.
fn for_target_is_mutable(target Expr, name string) bool {
	if target is Name {
		return (target as Name).id == name && (target as Name).is_mutable
	}
	if target is Tuple || target is List {
		elts := if target is Tuple { target.elts } else { (target as List).elts }
		for e in elts {
			if e is Name && (e as Name).id == name {
				return (e as Name).is_mutable
			}
		}
	}
	return false
}

// for_target_names returns the plain names a for-loop target binds.
fn for_target_names(target Expr) []string {
	if target is Tuple || target is List {
		mut out := []string{}
		elts := if target is Tuple { target.elts } else { (target as List).elts }
		for e in elts {
			if e is Name {
				out << (e as Name).id
			}
		}
		return out
	}
	if target is Name {
		return [(target as Name).id]
	}
	return []
}

// for_rebinds_parameter finds a loop target in the current function.
fn for_rebinds_parameter(body []Stmt, name string) bool {
	for stmt in body {
		match stmt {
			For, AsyncFor {
				if name in for_target_names(stmt.target) || for_rebinds_parameter(stmt.body, name)
					|| for_rebinds_parameter(stmt.orelse, name) {
					return true
				}
			}
			If, While {
				if for_rebinds_parameter(stmt.body, name) || for_rebinds_parameter(stmt.orelse, name) {
					return true
				}
			}
			With, AsyncWith {
				if for_rebinds_parameter(stmt.body, name) { return true }
			}
			Try {
				if for_rebinds_parameter(stmt.body, name) || for_rebinds_parameter(stmt.orelse, name)
					|| for_rebinds_parameter(stmt.finalbody, name)
					|| stmt.handlers.any(for_rebinds_parameter(it.body, name)) {
					return true
				}
			}
			Match {
				if stmt.cases.any(for_rebinds_parameter(it.body, name)) { return true }
			}
			else {}
		}
	}
	return false
}

// note_scope_binding records the V spelling a Python name is bound to in the
// function currently being emitted.
fn (mut t VTranspiler) note_scope_binding(py_name string) {
	t.scope_idents[t.binding_spelling(py_name)] = py_name
}

// binding_spelling returns the V identifier for a local Python binding.
fn (t VTranspiler) binding_spelling(py_name string) string {
	return t.renamed_idents[py_name] or { t.local_idents[py_name] or { escape_local_ident(py_name) } }
}

// is_bound_in_scope reports whether `py_name` is already a parameter or local of
// the function being emitted.
fn (t VTranspiler) is_bound_in_scope(py_name string) bool {
	return t.scope_idents[t.binding_spelling(py_name)] == py_name
}

// bind_op returns the operator that binds `v_name`. V rejects a second
// declaration of a name that is already bound in the function, and a Python
// loop target that shadows an existing name rebinds that same variable rather
// than introducing a new one, so this has to be an assignment.
fn (t VTranspiler) bind_op(v_name string) string {
	return if v_name in t.scope_idents { '=' } else { ':=' }
}

// visit_for emits V code for a For loop.
pub fn (mut t VTranspiler) visit_for(node For) string {
	if t.has_wide_destination(node.target) {
		return t.refuse_wide('unsigned storage requires a single scalar assignment')
	}
	saved_sum_sources := t.sum_list_kinds.clone()
	defer { t.sum_list_kinds = saved_sum_sources }
	sum_targets := for_target_names(node.target)
	iterator_kinds := python_sum_iter_kinds(t, node.iter)
	if sum_targets.len == iterator_kinds.len {
		for i, name in sum_targets {
			kind := match iterator_kinds[i] {
				'float_lists' { 'maybe_float' }
				'float', 'maybe_float' { 'float_value' }
				'int' { 'int_value' }
				else { '' }
			}
			t.sum_list_kinds[name] = kind
		}
	}
	saved_renames := t.renamed_idents.clone()
	mut rename := map[string]string{}
	mut writebacks := map[string]string{}
	mut preloop := []string{}
	for name in for_target_names(node.target) {
		spelling := t.binding_spelling(name)
		if spelling in t.loop_idents || spelling in t.scope_idents {
			fresh := if t.condition_walrus_vars[name] {
				t.new_tmp('walrus_iter')
			} else {
				t.fresh_loop_ident(name, rename)
			}
			if spelling in t.scope_idents && !t.is_bound_in_scope(name) {
				// A later reference to this Python name must never read a
				// different binding that happened to share the V spelling.
				t.local_idents[name] = fresh
			}
			// Only write back to the same Python binding. Distinct names can
			// acquire the same V spelling when a parameter is lowercased.
			if t.is_bound_in_scope(name) && (t.param_idents[name] or { true })
				&& !t.condition_walrus_vars[name] && for_target_is_mutable(node.target, name) {
				mut binding := spelling
				typ := t.var_types[name] or { '' }
				// Keep mutations of the caller's object before the loop, but
				// detach the Python name when the loop begins to rebind it.
				// A V `mut` parameter cannot itself be rebound without altering
				// the caller. Earlier writes must still go through that parameter.
				if name in t.param_idents && t.param_idents[name]
					&& t.local_idents[name] == escape_local_decl(name)
					&& typ !in v_value_param_types && typ !in ['', 'Any']
					&& !typ.starts_with('[]') && !typ.starts_with('map[')
					&& !typ.starts_with('&pyrt.ListRef[') && !typ.starts_with('?') {
					binding = t.new_tmp('param_rebind')
					preloop << 'mut ${binding} := ${spelling}'
					t.local_idents[name] = binding
					t.scope_idents[binding] = name
				}
				writebacks[name] = binding
				// V requires explicit sharing of array/map values, whereas a
				// Python loop target rebinds the reference without copying it.
				value := if typ.starts_with('[]') || typ.starts_with('map[') {
					'unsafe { ${fresh} }'
				} else {
					fresh
				}
				t.loop_prelude << '${binding} = ${value}'
			}
			rename[name] = fresh
		}
	}
	// Every name this loop binds is unbound again on the way out, so a later
	// loop reusing the same Python name is free to keep it.
	mut bound := []string{}
	for name in for_target_names(node.target) {
		fresh := rename[name] or { t.binding_spelling(name) }
		t.loop_idents[fresh] = true
		bound << fresh
	}
	for name, fresh in rename {
		t.renamed_idents[name] = fresh
	}
	defer {
		t.renamed_idents = saved_renames
		for fresh in bound {
			t.loop_idents.delete(fresh)
		}
	}
	mut target := t.visit_expr(node.target)
	mut buf := preloop.clone()

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
					iter_is_special = n in ['enumerate', 'zip']
				}
			}
			if target_names.len > 2 || (node.target is List && !iter_is_special) {
				seq := t.new_tmp('seq')
				item := t.new_tmp('item')
				buf << '${seq} := ${t.visit_for_iter(node.iter, saved_renames)}'
				buf << 'for ${item} in ${seq} {'
				for k, name in target_names {
					buf << t.indent_code('${name} ${t.bind_op(name)} ${item}[${k}]', 2)
				}
				body, flag := t.visit_for_body(node, 2, has_else, writebacks)
				buf << body
				buf << '\t}'
				t.emit_for_else(mut buf, node.orelse, flag, saved_renames)
				return buf.join('\n')
			}
			target = target_names.join(', ')

			// enumerate(seq) => for i, v in seq
			if node.iter is Call {
				call := node.iter as Call
				if call.func is Name {
					fname := (call.func as Name).id
					if fname == 'enumerate' && target_names.len == 2 && call.args.len > 0 {
						mut iter0 := t.visit_for_iter(call.args[0], saved_renames)
						if t.is_map_expr(call.args[0]) {
							iter0 = '${as_receiver(iter0)}.keys()'
						}
						mut index := target_names[0]
						mut offset := ''
						if start := enumerate_start(call) {
							if t.has_u64_bits(start) {
								return t.refuse_wide('enumerate start may narrow an unsigned value')
							}
							start_type := t.infer_expr_type(start)
							if start_type !in ['int', 'i64', 'bool'] {
								return t.unsupported_site('enumerate_start',
									'enumerate start needs a proven native integer', '')
							}
							items := t.new_tmp('enumerated')
							buf << '${items} := ${iter0}'
							iter0 = items
							offset = t.new_tmp('enum_start')
							start_expr := t.visit_for_iter(start, saved_renames)
							buf << '${offset} := ${if start_type == 'bool' {
								'int(${start_expr})'
							} else {
								start_expr
							}}'
							index = t.new_tmp('enum_index')
						}
						buf << 'for ${index}, ${target_names[1]} in ${iter0} {'
						if offset != '' {
							buf << '\t${target_names[0]} := ${index} + ${offset}'
						}
						body, flag := t.visit_for_body(node, 1, has_else, writebacks)
						buf << body
						buf << '}'
						t.emit_for_else(mut buf, node.orelse, flag, saved_renames)
						return buf.join('\n')
					}
					if fname == 'zip' && target_names.len == 2 && call.args.len == 2 {
						if call.keywords.len > 0 && !zip_disables_strict(call.keywords) {
							refusal := t.unsupported_site('zip_strict',
								'zip strict mismatch needs Python exception behavior', '')
							buf << '_ = ${refusal}'
						}
						first := t.new_tmp('zip_first')
						second := t.new_tmp('zip_second')
						length := t.new_tmp('zip_len')
						index := t.new_tmp('zip_index')
						for i, name in [first, second] {
							arg := call.args[i]
							source := t.visit_for_iter(arg, saved_renames)
							items := if t.infer_expr_type(arg) == 'string' {
								'${as_receiver(source)}.runes().map(it.str())'
							} else {
								source
							}
							buf << '${name} := ${items}'
						}
						buf << '${length} := if ${first}.len < ${second}.len { ${first}.len } else { ${second}.len }'
						buf << 'for ${index} in 0 .. ${length} {'
						buf << '\t${target_names[0]} ${t.bind_op(target_names[0])} ${first}[${index}]'
						buf << '\t${target_names[1]} ${t.bind_op(target_names[1])} ${second}[${index}]'
						body, flag := t.visit_for_body(node, 1, has_else, writebacks)
						buf << body
						buf << '}'
						t.emit_for_else(mut buf, node.orelse, flag, saved_renames)
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
			if fname == 'range' && call.args.len == 3
				&& is_literal_zero_range_step(call.args[2]) {
				return t.unsupported_site('range_zero_step', 'range() step must not be zero', '')
			}
			if fname == 'range' && t.has_wide_args(call.args) {
				for_expr = t.refuse_wide('range may narrow an unsigned bound')
			} else if call.api == '__py2v__.native_range_loop' && call.args.len in [1, 2] {
				start := if call.args.len == 1 {
					'0'
				} else {
					t.visit_for_iter(call.args[0], saved_renames)
				}
				end := t.visit_for_iter(call.args.last(), saved_renames)
				for_expr = '${start} .. ${end}'
			} else if fname == 'range' && call.args.len in [1, 2, 3]
				&& call.args.all(is_v_int_type(t.division_operand_type(it, t.infer_expr_type(it)))) {
				start := if call.args.len > 1 {
					t.visit_for_iter(call.args[0], saved_renames)
				} else {
					'0'
				}
				end_expr := call.args[if call.args.len > 1 { 1 } else { 0 }]
				end := t.visit_for_iter(end_expr, saved_renames)
				unit_step := call.args.len < 3 || (literal_word(call.args[2]) or { 0 }) == 1
				if unit_step {
					mut first := 'int(${start})'
					mut stop := 'int(${end})'
					if call.args.len > 1 && call.args[0] !is Constant {
						name := t.new_tmp('range_start')
						buf << '${name} := ${first}'
						first = name
					}
					// V rejects empty constant ranges. Keeping the bound in a local
					// preserves Python's empty iteration and for/else behavior.
					lower := if call.args.len > 1 {
						literal_word(call.args[0]) or { max_unsigned_word }
					} else {
						u64(0)
					}
					upper := literal_word(end_expr) or { 0 }
					if lower >= upper {
						name := t.new_tmp('range_stop')
						buf << '${name} := ${stop}'
						stop = name
					}
					buf << 'for ${target} in ${first} .. ${stop} {'
					body, flag := t.visit_for_body(node, 1, has_else, writebacks)
					buf << body
					buf << '}'
					t.emit_for_else(mut buf, node.orelse, flag, saved_renames)
					return buf.join('\n')
				}
				step := if call.args.len == 3 {
					t.visit_for_iter(call.args[2], saved_renames)
				} else {
					'1'
				}
				initial := t.new_tmp('range_start')
				stop := t.new_tmp('range_stop')
				stride := t.new_tmp('range_step')
				next := t.runtime_helper('range_next')
				// Keep discards and encoded spellings out of the range control.
				counter := if target == '_' || target.starts_with('py2v_ident_') {
					t.new_tmp('range_item')
				} else {
					target
				}
				buf << '${initial} := int(${start})'
				buf << '${stop} := int(${end})'
				buf << '${stride} := int(${step})'
				buf << "if ${stride} == 0 { panic('ValueError: range() arg 3 must not be zero') }"
				buf << 'for ${counter} := ${initial}; if ${stride} > 0 { ${counter} < ${stop} } else { ${counter} > ${stop} }; ${counter} = ${next}(${counter}, ${stop}, ${stride}) {'
				if counter != target && target != '_' {
					buf << '\t${target} := ${counter}'
				}
				body, flag := t.visit_for_body(node, 1, has_else, writebacks)
				buf << body
				buf << '}'
				t.emit_for_else(mut buf, node.orelse, flag, saved_renames)
				return buf.join('\n')
			} else {
				for_expr = t.visit_for_iter(node.iter, saved_renames)
			}
		} else {
			for_expr = t.visit_for_iter(node.iter, saved_renames)
		}
	} else {
		for_expr = t.visit_for_iter(node.iter, saved_renames)
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
	body, flag := t.visit_for_body(node, 1, has_else, writebacks)
	buf << body
	buf << '}'
	t.emit_for_else(mut buf, node.orelse, flag, saved_renames)

	return buf.join('\n')
}

// visit_for_iter reads the iterable before the loop target rebinds its names.
fn (mut t VTranspiler) visit_for_iter(expr Expr, before map[string]string) string {
	inside := t.renamed_idents
	t.renamed_idents = before
	defer { t.renamed_idents = inside }
	return t.visit_expr(expr)
}

// zip_disables_strict recognizes the explicit default for a two-input zip.
fn zip_disables_strict(keywords []Keyword) bool {
	if keywords.len != 1 || (keywords[0].arg or { '' }) != 'strict' {
		return false
	}
	value := keywords[0].value
	return value is Constant && value.value is bool && !(value.value as bool)
}

fn enumerate_start(call Call) ?Expr {
	if call.args.len == 2 && call.keywords.len == 0 {
		return call.args[1]
	}
	if call.args.len == 1 && call.keywords.len == 1 {
		keyword := call.keywords[0]
		if (keyword.arg or { '' }) == 'start' {
			return keyword.value
		}
	}
	return none
}

// loop_rebinds detects rebinding of a for-loop value inside its body.
fn loop_rebinds(body []Stmt, name string) bool {
	for stmt in body {
		match stmt {
			Assign {
				if stmt.targets.any(name in for_target_names(it)) { return true }
			}
			AnnAssign {
				if name in for_target_names(stmt.target) { return true }
			}
			AugAssign {
				if name in for_target_names(*stmt.target) { return true }
			}
			If {
				if loop_rebinds(stmt.body, name) || loop_rebinds(stmt.orelse, name) { return true }
			}
			While {
				if loop_rebinds(stmt.body, name) { return true }
			}
			For {
				if name in for_target_names(stmt.target) || loop_rebinds(stmt.body, name)
					|| loop_rebinds(stmt.orelse, name) {
					return true
				}
			}
			else {}
		}
	}
	return false
}

// visit_for_body makes a local copy of mutable loop values, preserving pointer identity
// while keeping rebinding local instead of changing the source container's element.
fn (mut t VTranspiler) visit_for_body(node For, level int, has_else bool, writebacks map[string]string) (string, string) {
	targets := match node.target {
		Tuple { node.target.elts }
		List { node.target.elts }
		else { [*node.target] }
	}
	mut saved := map[string]string{}
	mut locals := []string{}
	defer {
		for local in locals { t.scope_idents.delete(local) }
	}
	for target in targets {
		if target is Name && (get_expr_annotation(target).starts_with('&pyrt.ListRef[')
			|| loop_rebinds(node.body, target.id)) {
			saved[target.id] = t.renamed_idents[target.id] or { '' }
			if binding := writebacks[target.id] {
				t.renamed_idents[target.id] = binding
				continue
			}
			incoming := t.visit_expr(target)
			local := t.new_tmp('iter_value')
			t.loop_prelude << if get_expr_annotation(target).starts_with('&pyrt.ListRef[') {
				'mut ${local} := unsafe { ${incoming} }'
			} else {
				'mut ${local} := ${incoming}'
			}
			t.renamed_idents[target.id] = local
			t.note_scope_binding(target.id)
			locals << local
		}
	}
	// The control value is bounded independently of mutations of the sequence.
	// A rebinding gives the Python variable a different emitted name.
	mut range_binding := ''
	if node.target is Name && node.iter is Call && node.iter.func is Name
		&& node.iter.func.id == 'range' && node.iter.args.len in [1, 2]
		&& node.iter.keywords.len == 0 && 'range' !in t.func_return_types
		&& !t.is_bound_in_scope('range') && node.target.api == '__py2v__.range_induction'
		&& node.target.id !in t.global_vars && node.target.id !in writebacks
		&& !loop_rebinds(node.body, node.target.id) {
		bounds := t.native_integer_bounds(node.iter.args.last())
		start := if node.iter.args.len == 1 {
			i64(0)
		} else {
			literal_signed_integer(node.iter.args[0]) or { native_integer_min }
		}
		if bounds.high > start {
			range_binding = t.binding_spelling(node.target.id)
			t.integer_loop_bounds[range_binding] = NativeIntegerBounds{start, bounds.high - 1}
		}
	}
	body, flag := t.visit_loop_body(node.body, level, has_else)
	if range_binding != '' { t.integer_loop_bounds.delete(range_binding) }
	for name, previous in saved {
		if previous == '' {
			t.renamed_idents.delete(name)
		} else {
			t.renamed_idents[name] = previous
		}
	}
	return body, flag
}

// LoopBreak is one loop whose body is being emitted. A loop with an `else`
// gets a flag the first time one of its own `break`s is emitted; a nested
// loop has its own entry, so its breaks never set the flag.
struct LoopBreak {
mut:
	has_else     bool
	flag         string
	copy_targets map[string][]string
}

// visit_loop_body emits a loop body and returns it with the name of the flag
// its `break`s set, or '' when the loop has no else or no break of its own.
fn (mut t VTranspiler) visit_loop_body(stmts []Stmt, level int, has_else bool) (string, string) {
	mut condition_renames := map[string]string{}
	mut prefix := []string{}
	for name in t.condition_walrus_order {
		if iter := t.renamed_idents[name] {
			if t.loop_idents[iter] {
				condition_renames[name] = iter
				t.renamed_idents.delete(name)
				prefix << '${t.visit_name(Name{ id: name })} = ${iter}'
			}
		}
	}
	defer {
		for name, iter in condition_renames { t.renamed_idents[name] = iter }
	}
	t.loop_breaks << LoopBreak{
		has_else:     has_else
		copy_targets: growth_copy_targets(stmts)
	}
	mut first := t.loop_prelude.clone()
	t.loop_prelude = []string{}
	first << prefix
	mut body := t.visit_body_stmts(stmts, level)
	if first.len > 0 {
		body = t.indent_code(first.join('\n'), level) + '\n' + body
	}
	flag := t.loop_breaks.last().flag
	t.loop_breaks.delete_last()
	return body, flag
}

// visit_break emits a `break`, setting the innermost loop's flag first when
// that loop has an else the break must skip.
fn (mut t VTranspiler) visit_break() string {
	if !t.loop_breaks.last().has_else {
		return 'break'
	}
	i := t.loop_breaks.len - 1
	if t.loop_breaks[i].flag == '' {
		t.loop_breaks[i].flag = t.new_tmp('broke')
	}
	return '${t.loop_breaks[i].flag} = true\nbreak'
}

// emit_for_else emits the else of a for loop after its body. buf[0] holds the
// flag declaration visit_for wrote; a loop without a break keeps it as is.
fn (mut t VTranspiler) emit_for_else(mut buf []string, orelse []Stmt, flag string, before map[string]string) {
	if orelse.len == 0 {
		return
	}
	t.renamed_idents = before.clone()
	if flag == '' {
		buf << 'if has_break != true {'
	} else {
		buf[0] = 'mut ${flag} := false'
		buf << 'if !${flag} {'
	}
	buf << t.visit_body_stmts(orelse, 1)
	buf << '}'
}

struct GeneratorSignature {
	yield_type    string
	channel_first bool
	args          Arguments
}

struct GeneratorCallArgs {
	prefix  []string
	ordered []string
	valid   bool
}

// ordered_generator_call binds Python positional and keyword arguments to the
// generator's V signature (positional, keyword-only, then variadic). Evaluate
// caller expressions in Python order before rearranging them.
fn (mut t VTranspiler) ordered_generator_call(call Call, sig GeneratorSignature) GeneratorCallArgs {
	if sig.args.kwarg != none {
		return GeneratorCallArgs{}
	}
	mut positional := sig.args.posonlyargs.clone()
	positional << sig.args.args
	mut named := map[string]string{}
	mut extras := []string{}
	mut prefix := []string{}
	mut available := positional.map(it.arg)
	available << sig.args.kwonlyargs.map(it.arg)
	for i, arg in call.args {
		if arg is Starred {
			return GeneratorCallArgs{}
		}
		tmp := t.new_tmp('gen_arg')
		prefix << '${tmp} := ${t.visit_expr(arg)}'
		if i < positional.len {
			named[positional[i].arg] = tmp
		} else if sig.args.vararg != none {
			extras << tmp
		} else {
			return GeneratorCallArgs{}
		}
	}
	for kw in call.keywords {
		name := kw.arg or { return GeneratorCallArgs{} }
		if name !in available || name in named {
			return GeneratorCallArgs{}
		}
		tmp := t.new_tmp('gen_arg')
		prefix << '${tmp} := ${t.visit_expr(kw.value)}'
		named[name] = tmp
	}
	mut defaults := map[string]string{}
	for i, value in sig.args.defaults {
		idx := positional.len - sig.args.defaults.len + i
		if idx < 0 || !call_literal_default(value) {
			return GeneratorCallArgs{}
		}
		defaults[positional[idx].arg] = t.visit_expr(value)
	}
	for i, value in sig.args.kw_defaults {
		if expr := value {
			if !call_literal_default(expr) {
				return GeneratorCallArgs{}
			}
			defaults[sig.args.kwonlyargs[i].arg] = t.visit_expr(expr)
		}
	}
	mut ordered := []string{}
	for param in positional {
		if value := named[param.arg] {
			ordered << value
			continue
		}
		if value := defaults[param.arg] {
			ordered << value
			continue
		}
		return GeneratorCallArgs{}
	}
	for param in sig.args.kwonlyargs {
		if value := named[param.arg] {
			ordered << value
			continue
		}
		if value := defaults[param.arg] {
			ordered << value
			continue
		}
		return GeneratorCallArgs{}
	}
	ordered << extras
	return GeneratorCallArgs{
		prefix:  prefix
		ordered: ordered
		valid:   true
	}
}

// visit_async_for emits V code for an AsyncFor loop (converted to sync).
pub fn (mut t VTranspiler) visit_async_for(node AsyncFor) string {
	mut buf := []string{}
	target := t.visit_expr(node.target)
	if node.iter is Call {
		iter_call := node.iter as Call
		producer := t.visit_expr(iter_call.func)
		mut producer_args := []string{}
		mut arg_prefix := []string{}
		mut ordered := false
		ch := t.new_tmp('ch')
		buf << '// async for lowered to goroutine + channel'
		// The channel has the element type its producer was declared with
		mut elem_type := t.infer_iter_elem_type(node.iter)
		mut channel_first := false
		if iter_call.func is Name {
			if sig := t.generator_signatures[iter_call.func.id] {
				elem_type = sig.yield_type
				channel_first = sig.channel_first
				if sig.args.kwonlyargs.len > 0 || sig.args.defaults.len > 0
					|| iter_call.keywords.len > 0 {
					bound := t.ordered_generator_call(iter_call, sig)
					if !bound.valid {
						return '// TODO(py2v): unsupported generator call arguments\\npy2v_unsupported_generator_arguments()'
					}
					arg_prefix = bound.prefix
					producer_args = bound.ordered
					ordered = true
				}
			}
		}
		if !ordered {
			for arg in iter_call.args {
				producer_args << t.visit_expr(arg)
			}
			for kw in iter_call.keywords {
				producer_args << t.visit_expr(kw.value)
			}
		}
		buf << arg_prefix
		ch_type := if elem_type.len > 0 { elem_type } else { 'Any' }
		buf << '${ch} := chan ${ch_type}{}'
		if channel_first {
			producer_args.prepend(ch)
		} else {
			producer_args << ch
		}
		buf << 'go ${producer}(${producer_args.join(', ')})'
		buf << 'for {'
		buf << '\t${target} := <-${ch} or { break }'
		body, _ := t.visit_loop_body(node.body, 1, false)
		buf << body
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
			body, _ := t.visit_loop_body(node.body, 1, false)
			buf << body
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
			body, _ := t.visit_loop_body(node.body, 1, false)
			buf << body
			buf << '}'
			return buf.join('\n')
		}
	}

	test := t.if_condition(node.test)
	buf << 'for ${test} {'
	body, flag := t.visit_loop_body(node.body, 1, node.orelse.len > 0)
	buf << body
	buf << '}'
	if node.orelse.len > 0 {
		if flag == '' {
			// Nothing leaves the loop early, so the else always runs.
			buf << t.visit_body_stmts(node.orelse, 0)
		} else {
			buf.insert(0, 'mut ${flag} := false')
			buf << 'if !${flag} {'
			buf << t.visit_body_stmts(node.orelse, 1)
			buf << '}'
		}
	}

	return buf.join('\n')
}

// visit_if emits V code for an If statement.
pub fn (mut t VTranspiler) visit_if(node If) string {
	return t.visit_if_chain(node, false)
}

// visit_if_chain emits an if statement; is_elif is set for the `if` that
// follows `} else ` in an elif chain.
fn (mut t VTranspiler) visit_if_chain(node If, is_elif bool) string {
	mut buf := []string{}

	// A bare walrus as the whole condition (`if (ok := check(x)):`): hoist the
	// assignment and test the name, as the comparison form below does. V has
	// no assignment expression, so `if (ok := check(x)) {` does not parse.
	// Only when the frontend marked it (nothing else binds the name, and an
	// unannotated function doesn't return it). An elif test is emitted
	// unchanged: a hoisted line would land after `} else`.
	if node.test is NamedExpr && !is_elif && (node.test as NamedExpr).hoist
		&& !t.lower_this_condition(node) {
		ne := node.test as NamedExpr
		target := t.visit_expr(ne.target)
		// Record the name's type as visit_assign does for `name = value`.
		inferred := t.infer_expr_type(ne.value)
		if inferred.len > 0 {
			t.var_types[(ne.target as Name).id] = inferred
		}
		buf << '${target} := ${t.visit_expr(ne.value)}'
		buf << 'if ${target} {'
	} else if t.lower_this_condition(node) {
		test := t.lower_if_walrus_expr(*node.test, mut buf)
		buf << 'if ${t.visit_expr(test)} {'
	} else if has_walrus_in_compare(node.test) {
		parts := t.extract_walrus_parts(node.test)
		if parts.len == 2 {
			buf << parts[0]
			buf << 'if ${parts[1]} {'
		} else {
			test := t.visit_expr(node.test)
			buf << 'if ${test} {'
		}
	} else if !is_elif {
		test := t.bind_chain_middle(*node.test, mut buf)
		buf << 'if ${t.if_condition(test)} {'
	} else {
		buf << 'if ${t.if_condition(node.test)} {'
	}
	buf << t.visit_body_stmts(node.body, 1)

	if node.orelse.len > 0 {
		// Check if it's an elif
		if node.orelse.len == 1 && node.orelse[0] is If {
			else_if := node.orelse[0] as If
			if t.lower_this_condition(else_if) {
				buf << '} else {'
				buf << t.indent_code(t.visit_if(else_if), 1)
				buf << '}'
			} else {
				buf << '} else ${t.visit_if_chain(else_if, true)}'
			}
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

// visit_with emits a scope block so a return exits the enclosing function.
pub fn (mut t VTranspiler) visit_with(node With) string {
	mut buf := []string{}

	buf << '{'
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
			is_condition_local := vars is Name
				&& t.condition_walrus_vars[(vars as Name).id]
			if is_condition_local { kw = '' }
			op := if is_condition_local { '=' } else { ':=' }
			buf << '\t${kw}${target} ${op} ${context}'
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
	if node.mode == 'reraise' {
		// a bare `raise` in a handler: the error that handler's try caught goes on
		return t.escape_exception('py2v_raised_${node.guard}')
	}
	if node.mode in ['native_guard', 'native_result'] {
		name := raised_name(node)
		if name != '' {
			exc := node.exc or { panic('native exception without a value') }
			mut values := []string{}
			if exc is Call {
				for arg in exc.args {
					code := t.visit_expr(arg)
					values << if get_v_annotation(arg) == 'int' {
						'Py2vErrorArg(i64(${code}))'
					} else {
						'Py2vErrorArg(${code})'
					}
				}
			}
			args := if values.len == 0 { '[]Py2vErrorArg{}' } else { '[${values.join(', ')}]' }
			mut fields := 'args: Py2vErrorArgs{ values: ${args} }'
			if cause := node.cause {
				if cause is Name {
					fields += ', cause: ${t.visit_expr(cause)}.original'
				}
			}
			value := 'IError(Py2vError${name}{ data: Py2vErrorData{ ${fields} } })'
			if node.mode == 'native_guard' {
				return 'py2v_err_${node.guard} = ${value}\nbreak py2v_try_${node.guard}'
			}
			return t.escape_exception(value)
		}
	}
	mut exits := false
	if exc := node.exc {
		if exc is Name {
			exits = exc.id == 'SystemExit'
		} else if exc is Call && exc.func is Name {
			exits = exc.func.id == 'SystemExit'
		}
	}
	exits = exits && 'SystemExit' !in t.known_classes
	if exits && node.mode == '' && !t.fn_returns_result && t.exit_finally_bodies.len == 0 {
		if plain := t.plain_system_exit(node) {
			return plain
		}
	}
	if node.mode in ['result', 'guard'] || exits {
		if made := t.raised_error(node) {
			t.add_using('pyrt')
			if node.mode == 'guard' {
				return 'py2v_err_${node.guard} = ${made}\nbreak py2v_try_${node.guard}'
			}
			if t.fn_returns_result {
				return 'return ${made}'
			}
			if exits {
				if t.exit_finally_bodies.len > 0 {
					// Evaluate the exit argument once, before the cleanup's side effects.
					name := t.new_tmp('py2v_exit')
					mut lines := ['${name} := ${made}']
					saved_finally := t.exit_finally_bodies.clone()
					for i := saved_finally.len - 1; i >= 0; i-- {
						// A new exit in this cleanup supersedes the old one, but must
						// still execute the finalizers enclosing this cleanup.
						t.exit_finally_bodies = saved_finally[..i].clone()
						for stmt in saved_finally[i] {
							lines << t.visit_stmt(stmt)
						}
					}
					t.exit_finally_bodies = saved_finally
					lines << 'pyrt.fail(${name})'
					return lines.join('\n')
				}
				return 'pyrt.fail(${made})'
			}
		}
	}
	if exc := node.exc {
		mut msg := ''
		if exc is Call {
			call := exc as Call
			fname := t.visit_expr(call.func)
			arg := if call.args.len > 0 { t.visit_expr(call.args[0]) } else { "''" }
			msg = "'${fname}: ' + ${arg}"
		} else if exc is Name {
			msg = "'${t.visit_expr(exc)}'"
		} else {
			// Any other expression (`raise box['error']`) is a value: quoting its
			// source would put its own quotes inside the string.
			msg = '(${t.visit_expr(exc)}).str()'
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

fn raised_name(node Raise) string {
	exc := node.exc or { return '' }
	if exc is Name {
		return exc.id
	}
	if exc is Call && exc.func is Name {
		return (exc.func as Name).id
	}
	return ''
}

fn (mut t VTranspiler) escape_exception(value string) string {
	if t.active_error_guard > 0 {
		guard := t.active_error_guard
		return 'py2v_err_${guard} = ${value}\nbreak py2v_try_${guard}'
	}
	if t.in_entry && t.native_exceptions.len > 0 {
		t.entry_returns_result = true
		return 'return ${value}'
	}
	if t.fn_returns_result {
		return 'return ${value}'
	}
	return t.report_uncaught_error(value)
}

fn (mut t VTranspiler) report_uncaught_error(value string) string {
	if t.native_exceptions.len == 0 {
		t.add_using('pyrt')
		return 'pyrt.fail(${value})'
	}
	t.reports_native_error = true
	return '${t.runtime_helper_name('uncaught_exception')}(${value})'
}

fn (mut t VTranspiler) native_exception_declarations() []string {
	if t.native_exceptions.len == 0 {
		return []
	}
	mut definitions := [r"type Py2vErrorArg = bool | i64 | string

fn (arg Py2vErrorArg) str() string {
	return match arg {
		bool { if arg { 'True' } else { 'False' } }
		i64 { arg.str() }
		string { arg }
	}
}

struct Py2vErrorArgs {
	values []Py2vErrorArg
}

fn (args Py2vErrorArgs) str() string {
	mut parts := []string{cap: args.values.len}
	for value in args.values {
		if value is string {
			quote := if value.contains('\x27') && !value.contains('\x22') { '\x22' } else { '\x27' }
			escaped := value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t').replace(quote, '\\' + quote)
			parts << quote + escaped + quote
		} else {
			parts << value.str()
		}
	}
	suffix := if parts.len == 1 { ',)' } else { ')' }
	return '(' + parts.join(', ') + suffix
}

struct Py2vErrorData {
	args Py2vErrorArgs
	original ?IError
	cause ?IError
}

fn (data Py2vErrorData) str() string {
	if data.args.values.len > 1 {
		return data.args.str()
	}
	value := data.args.values[0] or { return '' }
	return value.str()
}"]
	names := t.native_exceptions.keys().sorted()
	for name in names {
		typ := 'Py2vError${name}'
		definitions << 'struct ${typ} {\n\tError\n\tdata Py2vErrorData\n}'
		definitions << 'fn (err ${typ}) msg() string {\n\treturn err.data.str()\n}'
	}
	if t.binds_native_error {
		bind := t.runtime_helper_name('bind_exception')
		cases := names.map('\t\tPy2vError${it} { Py2vErrorData{ ...err.data, original: IError(err) } }').join('\n')
		definitions << 'fn ${bind}(err IError) Py2vErrorData {\n\treturn match err {\n${cases}\n\t\telse { panic(err) }\n\t}\n}'
	}
	if t.reports_native_error {
		report := t.runtime_helper_name('uncaught_exception')
		cases := names.map("\t\tPy2vError${it} { '${it}' }").join('\n')
		definitions << "@[noreturn]\nfn ${report}(err IError) {\n\tclass_name := match err {\n${cases}\n\t\telse { panic(err) }\n\t}\n\tmessage := err.msg()\n\teprintln(if message == '' { class_name } else { class_name + ': ' + message })\n\texit(1)\n}"
	}
	return definitions
}

// plain_system_exit emits literal exit codes or messages once an exception can
// leave directly. Other arguments still need Python's runtime classification.
fn (mut t VTranspiler) plain_system_exit(node Raise) ?string {
	exc := node.exc or { return none }
	if exc is Name {
		return 'exit(0)'
	}
	if exc is Call && exc.keywords.len == 0 {
		if exc.args.len == 0 {
			return 'exit(0)'
		}
		if exc.args.len == 1 && exc.args[0] is Constant {
			arg := exc.args[0] as Constant
			return match arg.value {
				NoneValue { 'exit(0)' }
				bool {
					if arg.value as bool { 'exit(1)' } else { 'exit(0)' }
				}
				int { 'exit(${arg.value as int})' }
				i64 { 'exit(int(${arg.value as i64}))' }
				string { 'eprintln(${t.visit_expr(arg)})\nexit(1)' }
				else { none }
			}
		}
	}
	return none
}

// raised_error is the V error value of `raise C(args)` or `raise C`: the runtime's
// exception of that class with its arguments as runtime values, and for a class of the
// translated file its bases, so that handlers naming a base take it.
fn (mut t VTranspiler) raised_error(node Raise) ?string {
	exc := node.exc or { return none }
	mut class_name := ''
	mut args := []string{}
	mut text := ''
	if exc is Call {
		func := exc.func
		if func is Name {
			class_name = func.id
		}
		for arg in exc.args {
			code := t.visit_expr(arg)
			if exc.args.len == 1 && code.starts_with("'") {
				text = code
			}
			args << if code.starts_with('pyrt.') { code } else { 'pyrt.box(${code})' }
		}
	} else if exc is Name {
		class_name = exc.id
	}
	if class_name == '' {
		return none
	}
	if text != '' && node.bases.len == 0 {
		// the usual form: one message
		return "pyrt.raise('${class_name}', ${text})"
	}
	list := if args.len == 0 { '[]pyrt.Value{}' } else { '[${args.join(', ')}]' }
	if node.bases.len > 0 {
		bases := node.bases.map("'${it}'").join(', ')
		return "IError(pyrt.exception_of('${class_name}', [${bases}], ${list}))"
	}
	return "IError(pyrt.exception('${class_name}', ${list}))"
}

// visit_try emits V code for a Try statement.
// V uses Result types and `or {}` blocks instead of exceptions; we emit the
// try body as-is and each except handler inside an `// except` comment header
// followed by the handler body as real (but guarded) V code so it stays visible
// and compilable after manual adaptation.
// visit_try lowers Python's try/except/else/finally.
//
// V has no exception mechanism. It reports failure through a `Result` that the
// caller has to unwrap with `or {}` or `!`, so a `try` block cannot be
// reproduced unless every fallible statement inside it has already been wrapped.
// py2v wraps some of them and not others, and an unwrapped failure reaches
// `panic`, which nothing can catch.
//
// Rather than emit a handler that references an exception variable nothing ever
// bound — which both fails to compile and reads as if it worked — the body is
// emitted and the handlers are reported. `finally` is the exception: it maps
// cleanly onto `defer`, so it keeps its code. `else` is dropped because it is
// unreachable once no exception can be observed.
pub fn (mut t VTranspiler) visit_try(node Try) string {
	if node.guard > 0 {
		if node.finalbody.len > 0 {
			mut block := []string{}
			t.emit_try_finally_defer(mut block, node.finalbody)
			block << t.visit_guarded_try(node)
			return '{\n${t.indent_code(block.join('\n'), 1)}\n}'
		}
		return t.visit_guarded_try(node)
	}
	mut buf := []string{}

	// V refuses a `defer` inside a `defer`. Inside one, the cleanup of an inner
	// `try` runs straight after its body instead: nothing can leave that body
	// early, because V also refuses `return` inside `defer` and a panic runs no
	// cleanup at all. A `break` or `continue` that would skip the cleanup is the
	// one exception, and it is reported by a call to a function that does not exist.
	finally_in_defer := t.defer_depth > 0 && node.finalbody.len > 0
	if finally_in_defer {
		if stmts_jump_out_of_block(node.body) {
			buf << 'py2v_unsupported_jump_out_of_try_finally_inside_finally()'
		}
	} else {
		t.emit_try_finally_defer(mut buf, node.finalbody)
	}

	if node.finalbody.len > 0 {
		t.exit_finally_bodies << node.finalbody
	}
	for stmt in node.body {
		buf << t.visit_stmt(stmt)
	}
	if node.finalbody.len > 0 {
		t.exit_finally_bodies.pop()
	}
	if finally_in_defer {
		for stmt in node.finalbody {
			buf << t.visit_stmt(stmt)
		}
	}

	if node.orelse.len > 0 {
		buf << '// else: runs only when the try body raises, which no V construct here does'
		t.note_exception_handler('else clause', 1)
	}

	if node.handlers.len == 0 {
		return buf.join('\n')
	}

	buf << '// except handlers are not translated: see the TODO(py2v) note above'
	for handler in node.handlers {
		buf << t.describe_except_handler(handler)
	}
	return buf.join('\n')
}

// visit_guarded_try emits a `try` with handlers and no `finally` whose body the frontend
// planned: the body runs in a one-shot labeled loop that the first failing call leaves
// (see guarded_call); after it, the first handler whose classes match the error runs,
// or the `else` block when nothing failed. An error no handler takes is returned from a
// function that returns a result, and ends the program elsewhere.
fn (mut t VTranspiler) visit_guarded_try(node Try) string {
	n := node.guard
	native := t.native_exceptions.len > 0
	if !native {
		t.add_using('pyrt')
	}
	mut buf := []string{}
	buf << 'mut py2v_err_${n} := ?IError(none)'
	buf << 'py2v_try_${n}: for {'
	outer_guard := t.active_error_guard
	if native {
		t.active_error_guard = n
	}
	for stmt in node.body {
		buf << t.indent_code(t.visit_stmt(stmt), 1)
	}
	t.active_error_guard = outer_guard
	mut leaves := false
	if node.body.len > 0 {
		last := node.body.last()
		if last is Return {
			leaves = true
		} else if last is Raise {
			// a guarded `raise` has left the loop already
			leaves = last.mode in ['guard', 'native_guard'] && last.guard == n
		}
	}
	if !leaves {
		buf << '\tbreak'
	}
	buf << '}'
	head_at := buf.len
	buf << ''
	mut chain := []string{}
	mut takes_all := false
	for handler in node.handlers {
		mut body := []string{}
		for stmt in handler.body {
			body << t.indent_code(t.visit_stmt(stmt), 1)
		}
		name := handler.name or { '' }
		if handler.classes.len == 0 {
			// a bare `except:` takes every error
			takes_all = true
			chain << '{\n${body.join('\n')}\n}'
			break
		}
		if native {
			for class in handler.classes {
				if class !in t.native_exceptions {
					t.native_exceptions[class] = []string{}
				}
			}
			mut types := []string{}
			for class in t.native_exceptions.keys().sorted() {
				if class in handler.classes || t.native_exceptions[class].any(it in handler.classes) {
					types << 'py2v_raised_${n} is Py2vError${class}'
				}
			}
			if name != '' {
				t.binds_native_error = true
				bind := t.runtime_helper_name('bind_exception')
				body.prepend('\t${escape_local_decl(name)} := ${bind}(py2v_raised_${n})')
			}
			chain << 'if ${types.join(' || ')} {\n${body.join('\n')}\n}'
			continue
		}
		classes := handler.classes.map("'${it}'").join(', ')
		head := if name != '' {
			'if ${escape_local_decl(name)} := pyrt.caught(py2v_raised_${n}, ${classes}) '
		} else {
			'if pyrt.caught(py2v_raised_${n}, ${classes}) != none '
		}
		chain << '${head}{\n${body.join('\n')}\n}'
	}
	if !takes_all {
		escape := t.escape_exception('py2v_raised_${n}')
		chain << '{\n\t${escape}\n}'
	}
	chain_code := chain.join(' else ')
	// a bare `except:` that does not pass the error on never names it
	buf[head_at] = if chain_code.contains('py2v_raised_${n}') {
		'if py2v_raised_${n} := py2v_err_${n} {'
	} else {
		'if py2v_err_${n} != none {'
	}
	buf << t.indent_code(chain_code, 1)
	if node.orelse.len > 0 {
		buf << '} else {'
		for stmt in node.orelse {
			buf << t.indent_code(t.visit_stmt(stmt), 1)
		}
	} else if node.body.len > 0 && node.body.last() is Return {
		// The body always returns, so nothing follows a try that did not fail; V cannot
		// see that through the loop and asks for a return after it.
		buf << '} else {'
		buf << if native { "\tpanic('unreachable try completion')" } else { '\tpyrt.unreachable()' }
	}
	buf << '}'
	return buf.join('\n')
}

// describe_except_handler renders one handler as a comment and records that it
// needs a hand-written V equivalent.
fn (mut t VTranspiler) describe_except_handler(handler ExceptHandler) string {
	meta := t.build_except_handler_meta(handler)
	mut label := 'except'
	if meta.type_names.len > 0 {
		label = label + ' ${meta.type_names.join(' | ')}'
	}
	if meta.bound_name.len > 0 {
		label = label + ' as ${meta.bound_name}'
	}
	t.note_exception_handler(label, handler.body.len)
	return '//   ${label}: ${handler.body.len} statement(s) need an `or { ... }` equivalent'
}

// note_exception_handler records a clause that has no generated code, together
// with how many statements it covers, so the gap is reported once at module
// scope rather than at every occurrence.
pub fn (mut t VTranspiler) note_exception_handler(label string, statements int) {
	if label == '' {
		return
	}
	entry := '${label} (${statements} stmt)'
	if !(entry in t.exception_handlers) {
		t.exception_handlers << entry
	}
}

// exception_handler_comment renders the module-scope note listing every handler
// that was left for a human to translate.
pub fn (t VTranspiler) exception_handler_comment() string {
	if t.exception_handlers.len == 0 {
		return ''
	}
	mut handlers := t.exception_handlers.clone()
	handlers.sort()
	return '// TODO(py2v): ${handlers.len} except handler(s) need a V Result equivalent:\n' +
		'//   ' + handlers.join('\n//   ')
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

// ExceptHandlerMeta names what an except clause catches and binds.
struct ExceptHandlerMeta {
mut:
	header     string
	type_names []string
	bound_name string
}

// emit_try_finally_defer maps Python's `finally` onto V's `defer`, which runs
// when the enclosing function returns or panics. This is the one part of a
// Python `try` statement V can express directly.
fn (mut t VTranspiler) emit_try_finally_defer(mut buf []string, finalbody []Stmt) {
	if finalbody.len == 0 {
		return
	}
	buf << 'defer {'
	t.defer_depth++
	for stmt in finalbody {
		result := t.visit_stmt(stmt)
		for line in result.split('\n') {
			if line.len > 0 {
				buf << '\t${line}'
			}
		}
	}
	t.defer_depth--
	buf << '}'
}

// stmts_jump_out_of_block reports whether a `break` or `continue` in `stmts`
// leaves them, which is one that is not inside a loop of their own.
fn stmts_jump_out_of_block(stmts []Stmt) bool {
	for stmt in stmts {
		match stmt {
			Break, Continue {
				return true
			}
			If {
				if stmts_jump_out_of_block(stmt.body) || stmts_jump_out_of_block(stmt.orelse) {
					return true
				}
			}
			With {
				if stmts_jump_out_of_block(stmt.body) {
					return true
				}
			}
			AsyncWith {
				if stmts_jump_out_of_block(stmt.body) {
					return true
				}
			}
			Try {
				if stmts_jump_out_of_block(stmt.body) || stmts_jump_out_of_block(stmt.orelse)
					|| stmts_jump_out_of_block(stmt.finalbody) {
					return true
				}
				for h in stmt.handlers {
					if stmts_jump_out_of_block(h.body) {
						return true
					}
				}
			}
			else {}
		}
	}
	return false
}

// build_except_handler_meta names the exception types a handler catches and the
// name it binds them to, for use in a diagnostic comment.
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
	value := t.typename_from_annotation(*node.value)
	prefix := if t.emit_pub { 'pub ' } else { '' }
	if value.len > 0 {
		return '${prefix}type ${name} = ${value}'
	}
	return '${prefix}type ${name} = ${t.visit_expr(node.value)}'
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
			return '${cmp_operand(subject)} == ${cmp_operand(t.visit_expr(p.value))}'
		}
		MatchSingleton {
			return '${cmp_operand(subject)} == ${p.value}'
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
			return join_conditions(parts, '||')
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
				parts << '${as_receiver(subject)}.len >= ${fixed_len}'
			} else {
				parts << '${as_receiver(subject)}.len == ${p.patterns.len}'
			}
			mut elem_idx := 0
			for sp in p.patterns {
				if sp is MatchStar {
					continue
				}
				elem_cond := t.emit_pattern_condition('${as_receiver(subject)}[${elem_idx}]', sp)
				if elem_cond.len > 0 {
					parts << elem_cond
				}
				elem_idx++
			}
			return join_conditions(parts, '&&')
		}
		MatchMapping {
			mut parts := []string{}
			for i, k in p.keys {
				key_str := t.visit_expr(k)
				parts << '${cmp_operand(key_str)} in ${cmp_operand(subject)}'
				vp := p.patterns[i]
				val_cond := t.emit_pattern_condition('${as_receiver(subject)}[${key_str}]', vp)
				if val_cond.len > 0 {
					parts << val_cond
				}
			}
			return join_conditions(parts, '&&')
		}
		MatchClass {
			cls_str := t.visit_expr(p.cls)
			mut parts := []string{}
			parts << '${cmp_operand(subject)} is ${cls_str}'
			for i, attr in p.kwd_attrs {
				vp := p.kwd_patterns[i]
				val_cond := t.emit_pattern_condition('${as_receiver(subject)}.${attr}', vp)
				if val_cond.len > 0 {
					parts << val_cond
				}
			}
			return join_conditions(parts, '&&')
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
			t.comp_depth++
			mut guard_expr := t.visit_expr(guard)
			t.comp_depth--
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

		is_wildcard := full_cond == ''
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
		// `import a.b as c` binds the local name `c`, not `a`, so record both:
		// the alias for reference resolution and the module marker so that
		// `c.attr(...)` is not treated as a method call on a value.
		mut local := alias.name.split('.')[0]
		mut aliased := false
		if a2 := alias.asname {
			local = a2
			aliased = true
		}
		t.imported_modules[local] = true
		if aliased {
			t.module_aliases[local] = alias.name
		}
		t.init_import_aliases[local] = if aliased { alias.name } else { local }
	}
	return lines.filter(it.len > 0).join('\n')
}

// resolve_relative_import turns a Python relative import into an absolute
// dotted module path.
//
// `level` is the leading-dot count the frontend records but that nothing else
// consumed: level 1 is the current package, level 2 its parent, and so on.
// Dropping more levels than the package has depth lands on the scan root, which
// is where Python would fail to resolve it too.
pub fn (t VTranspiler) resolve_relative_import(level int, mod string) string {
	if level <= 0 {
		return mod
	}
	// `level` counts leading dots, so level 1 is the current package. The
	// package is the current module's own dotted path for a package `__init__`,
	// and the path without its last segment for an ordinary module.
	mut parts := t.current_dotted.split('.').filter(it.len > 0)
	if !t.current_is_package && parts.len > 0 {
		parts = parts[..parts.len - 1]
	}
	mut ascend := level - 1
	for ascend > 0 && parts.len > 0 {
		parts = parts[..parts.len - 1]
		ascend--
	}
	return join_dotted(parts.join('.'), mod)
}

// visit_import_from handles Python 'from X import Y', mapping the module.
pub fn (mut t VTranspiler) visit_import_from(node ImportFrom) string {
	constructor_module := t.init_import_module(node.level, node.mod or { '' })
	for alias in node.names {
		local := alias.asname or { alias.name }
		if local == '*' {
			for name in t.init_star_names(constructor_module) {
				t.init_import_aliases[name] = join_dotted(constructor_module, name)
			}
		} else if local != '' {
			t.init_import_aliases[local] = join_dotted(constructor_module, alias.name)
		}
	}
	module_name := t.resolve_relative_import(node.level, node.mod or { '' })
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
			if local == '' {
				// `from proj.mod import *`: every public name of that module
				// becomes visible unqualified, so record the module and let
				// bare references be resolved against it.
				t.add_star_import(module_name)
				continue
			}
			// A relative import names a sibling module; resolve it against the
			// current module's package.
			target := if module_name == '' { alias.name } else { module_name + '.' + alias.name }
			target_v := t.registry.v_module_for(target)
			if target_v == '' {
				// Not a module of this project; fall through.
			} else if target_v != t.module_name {
				t.imported_modules[local] = true
				t.import_aliases[local] = target_v
				t.import_prefixes[target_v] = true
				continue
			} else {
				// `from . import mod` binds a submodule that lands in the V
				// module already in scope, so `mod.symbol` collapses to
				// `symbol` at each use site.
				t.submodule_aliases[local] = target
				continue
			}
			if v_mod != t.module_name {
				t.import_aliases[local] = v_mod
				t.import_prefixes[v_mod] = true
			}
		}
		t.seed_imported_classes(module_name)
		return ''
	}
	return t.map_python_import(module_name)
}

// note_unresolved_import records a Python module that has no V counterpart, so
// the gap is reported once at module scope instead of turning into an undefined
// identifier at every use site.
pub fn (mut t VTranspiler) note_unresolved_import(py_module string) {
	if py_module == '' || py_module in t.unresolved_imports {
		return
	}
	t.unresolved_imports << py_module
}

// unmapped_call_base returns the leading segment of a qualified callee when
// that segment names a Python module with no V mapping, and an empty string
// otherwise. `ctypes.CDLL` qualifies on such a module; `obj.method` does not.
fn unmapped_call_base(fname string, unmapped map[string]bool) string {
	if fname in python_unmapped_names {
		return fname
	}
	if fname in python_unmapped_members {
		return fname
	}
	head, _ := fname.split_once('.') or { return '' }
	if unmapped[head] {
		return head
	}
	return ''
}

// note_unmapped_call records a call into a Python module with no V mapping.
pub fn (mut t VTranspiler) note_unmapped_call(text string) {
	if text == '' || text in t.unmapped_calls {
		return
	}
	t.unmapped_calls << text
}

// unmapped_call_comment renders the module-scope note listing every stubbed
// call, so that nothing is dropped without saying so.
pub fn (t VTranspiler) unmapped_call_comment() string {
	if t.unmapped_calls.len == 0 {
		return ''
	}
	mut calls := t.unmapped_calls.clone()
	calls.sort()
	return '// TODO(py2v): no V mapping for ' + calls.join(', ') +
		'\n// Each site below is stubbed with a zero value.'
}

// unresolved_import_comment renders the module-scope note listing every Python
// module that could not be mapped, or an empty string when there are none.
pub fn (t VTranspiler) unresolved_import_comment() string {
	if t.unresolved_imports.len == 0 {
		return ''
	}
	mut names := t.unresolved_imports.clone()
	names.sort()
	return '// TODO(py2v): no V equivalent for import ' + names.join(', ') +
		'\n// Provide one in python_to_v_import (types.v) or port the module.'
}

// project_import_name resolves an explicit Python import to the generated module.
// Keep the imported symbol's name: a local alias is not an export of its owner.
fn (mut t VTranspiler) project_import_name(path string) ?string {
	if path == '' { return none }
	if info := t.registry.by_dotted[path] {
		if info.v_module == t.module_name { return none }
		t.add_using(info.v_module)
		return info.v_module
	}
	if name := t.imported_colliding_function(path) {
		return name
	}
	if !path.contains('.') { return none }
	owner := t.registry.lookup(path.all_before_last('.'))
	if owner.dotted == '' { return none }
	symbol := path.all_after_last('.')
	mut name := escape_local_ident(symbol)
	if symbol in owner.value_symbols {
		naming := VTranspiler{
			...t
			module_name:  owner.v_module
			current_stem: v_file_stem(owner.v_relpath)
		}
		name = naming.module_value_name(symbol, naming.private_names_shared_with_siblings())
	}
	if owner.v_module == t.module_name { return name }
	t.add_using(owner.v_module)
	return '${owner.v_module}.${name}'
}

// Resolve a renamed definition through explicit imports, including re-exports.
fn (mut t VTranspiler) imported_colliding_function(path string) ?string {
	if t.registry.function_names.len == 0 { return none }
	mut target := path
	for _ in 0 .. max_reexport_hops {
		if !target.contains('.') { return none }
		info := t.registry.lookup(target.all_before_last('.'))
		if info.dotted == '' { return none }
		canonical := '${info.dotted}.${target.all_after_last('.')}'
		if binding := t.registry.init_import_bindings[canonical] {
			target = binding
			continue
		}
		name := t.registry.function_names[canonical] or { return none }
		if info.v_module == t.module_name { return name }
		t.add_using(info.v_module)
		return '${info.v_module}.${name}'
	}
	return none
}

// collapse_submodule_attr rewrites `mod.attr` to `attr` when `mod` was bound by
// `from . import mod` and that submodule lands in the V module already in scope.
//
// The qualifier has no V spelling: Python namespaces a submodule separately, V
// merges it into the package. Returns an empty string for any other attribute.
pub fn (t VTranspiler) collapse_submodule_attr(node Attribute) string {
	if node.value !is Name {
		return ''
	}
	target := t.submodule_aliases[(node.value as Name).id] or { return '' }
	if t.registry.v_module_for(target) != t.module_name {
		return ''
	}
	attr := python_dunder_method_names[node.attr] or { node.attr }
	return escape_keyword(escape_leading_underscore(attr))
}

// add_star_import records a `from X import *` so that a bare reference to a
// name defined in X can be qualified with X's V module.
pub fn (mut t VTranspiler) add_star_import(dotted string) {
	info := t.registry.lookup(dotted)
	if info.dotted == '' {
		return
	}
	if info.v_module == t.module_name {
		return
	}
	t.add_using(info.v_module)
	t.star_imports << info.v_module
}

// star_import_owner returns the V module that defines `name` among the modules
// reached through `from X import *`, or an empty string when none of them do.
//
// Names defined by the current module win, so a star import can never capture a
// local definition.
pub fn (t VTranspiler) star_import_owner(name string) string {
	mut result := ''
	for module in t.star_imports {
		if name in t.registry.symbols_named_in(t.registry.dotted_for_v_module(module)) {
			result = module
		}
	}
	return result
}

// map_python_import converts a Python module name to a V import line or comment.
fn (mut t VTranspiler) map_python_import(py_module string) string {
	// A module belonging to the scanned project maps to a V module of the same
	// layout, so it needs a real import rather than a "no equivalent" comment.
	if t.registry.contains(py_module) {
		if !t.registry.is_project_root(py_module)
			&& t.registry.v_module_for(py_module) != t.module_name {
			t.add_using(t.registry.v_module_for(py_module))
		}
		return ''
	}
	// Strip sub-module suffix for top-level lookup first
	top := py_module.split('.')[0]
	// Check exact match first, then top-level
	if !(py_module in python_to_v_import) && !(top in python_to_v_import) {
		t.note_unresolved_import(py_module)
		t.unmapped_modules[top] = true
		return ''
	}
	if v_mod_value := python_to_v_import[py_module] {
		if v_mod_value.starts_with('!') {
			t.note_unresolved_import(py_module)
			t.unmapped_modules[top] = true
			return ''
		}
	}
	v_mod := python_to_v_import[py_module] or { python_to_v_import[top] or { '' } }
	if v_mod == '' {
		return '' // silently suppressed
	}
	// A module the runtime library provides under the same V name: its calls import
	// `pyrt.<name>` themselves, and V refuses two imports with one name.
	if top in runtime_library_modules && v_mod.all_after_last('.') == top {
		return ''
	}
	if v_mod.starts_with('!') {
		t.note_unresolved_import(py_module)
		return ''
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
// as_any_slice widens a rendered array literal to a `[]Any`. The `.map` form is
// used rather than a `[]Any[...]` prefix because `v fmt`, which runs over every
// file py2v writes, rewrites that prefix into `[]Any{}` followed by an index
// expression, which no longer compiles.
fn as_any_slice(s string) string {
	t := s.trim_space()
	if !t.starts_with('[') || !t.ends_with(']') {
		return s
	}
	return '${as_receiver(t)}.map(Any(it))'
}

// expr_is_conversion reports whether a rendered expression is exactly one
// type conversion of the form `Type(arg)`. V reads those as a value expression
// rather than a statement call, so a discarded conversion needs `_ = `.
fn expr_is_conversion(expr string) bool {
	s := expr.trim_space()
	if !s.ends_with(')') {
		return false
	}
	open := s.index('(') or { return false }
	if open <= 0 {
		return false
	}
	if s[open..].count('(') != s[open..].count(')') {
		return false
	}
	return match s[..open] {
		'Any', 'bool', 'byte', 'char', 'f32', 'f64', 'i8', 'i16', 'i32', 'i64',
		'int', 'isize', 'rune', 'string', 'u8', 'u16', 'u32', 'u64', 'usize',
		'voidptr' {
			true
		}
		else {
			false
		}
	}
}

// visit_expr_stmt emits a Python expression statement.
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
	if expr_is_conversion(result) {
		return '_ = ${result}'
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
			return 'i64(${node.value as i64})'
		}
		u64 {
			return 'u64(${node.value as u64})'
		}
		f64 {
			value := (node.value as f64).str()
			return if value.contains_any('.eE') { value } else { value + '.0' }
		}
		string {
			if (node.kind or { '' }) == 'py2v_large_int' {
				t.add_using('math.big as py2v_big')
				return "py2v_big.integer_from_string('${node.value as string}') or { panic(err) }"
			}
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
	if name := t.renamed_class(node.class_path) {
		return name
	}
	if node.api in ['__py2v__.unsigned_bit_count', '__py2v__.unsigned_bit_length'] {
		return t.unsigned_bit_function(node.id)
	}
	if t.condition_walrus_vars[node.id] {
		if renamed := t.renamed_idents[node.id] { return renamed }
		if local := t.local_idents[node.id] { return local }
	}
	// Check if this identifier was escaped due to V built-in type name conflict
	if t.escaped_identifiers[node.id] or { false } {
		return '${node.id}_'
	}
	// A bare `_` is the Python throwaway target and stays as V's discard name.
	if node.id == '_' {
		return '_'
	}
	// A read of Python's `__file__`, which the frontend spells as V's `@FILE`.
	if node.id == '@FILE' {
		return node.id
	}
	// A name bound by `from math import name` is a member of V's math module.
	// A name bound by `from random import name` is spelled as the module member,
	// which visit_call maps to V's rand module.
	if node.math_member.starts_with('random.') {
		return node.math_member
	}
	if v_name := math_member_names[node.math_member] {
		t.add_using('math')
		return v_name
	}
	// A loop variable renamed to avoid shadowing an enclosing binding. This is
	// checked first: the scope pre-pass records an identity entry in
	// `local_idents` for every local it sees, and that entry would otherwise
	// mask the rename.
	if renamed := t.renamed_idents[node.id] {
		return renamed
	}
	// A local declared under a rewritten spelling must be referenced by it.
	if v_ident := t.local_idents[node.id] {
		return v_ident
	}
	// Likewise for a module-level binding such as a constant.
	if v_ident := t.module_idents[node.id] {
		return v_ident
	}
	if t.is_bound_in_scope(node.id) && node.id in t.init_import_aliases {
		return escape_local_ident(node.id)
	}
	if resolved := t.project_import_name(t.init_python_path(Expr(node))) {
		return resolved
	}
	// A name bound by `from other_module import name` lives in another V
	// module, so references must be qualified.
	if prefix := t.import_aliases[node.id] {
		return '${prefix}.${escape_local_ident(node.id)}'
	}
	// `from other_module import *` makes that module's names visible without a
	// binding, so they have to be qualified at every use site instead.
	star_prefix := t.star_import_owner(node.id)
	if star_prefix != '' {
		return '${star_prefix}.${escape_local_ident(node.id)}'
	}
	// Leave the unbound Python builtin available to call dispatch.
	if node.id == 'map' && node.ctx is Load && !t.is_bound_in_scope(node.id)
		&& !t.loop_idents[escape_local_ident(node.id)] && t.lambda_params[node.id] == 0 {
		return node.id
	}
	return escape_local_ident(node.id)
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

// Precedence of emitted code that binds like a name, a call or a parenthesized
// expression: it can take a `.field` or an index.
const atom_prec = 10

// Precedence of a prefix operation (`-x`, `!x`, `~x`): it binds tighter than any binary
// operator, but `-x.abs()` applies the method to `x` alone.
const prefix_prec = 9

// v_prec returns V's precedence for the binary operator `op`, from 5 (`*`) down to 1
// (`||`), or -1 when `op` is not one; V's table is not Python's (`&`, `<<` and `>>` bind
// like `*`, `|` and `^` like `+`).
fn v_prec(op string) int {
	return match op {
		'*', '/', '%', '<<', '>>', '>>>', '&' { 5 }
		'+', '-', '|', '^' { 4 }
		'==', '!=', '<', '<=', '>', '>=', 'in', '!in', 'is', '!is' { 3 }
		'&&' { 2 }
		'||' { 1 }
		'or', 'as' { 0 }
		else { -1 }
	}
}

// code_prec returns the precedence emitted V code binds at, read from the code itself, so
// it holds for every lowering: the lowest binary operator at its top level (outside
// brackets and strings), 0 for an `if`, `match` or `fn` expression or a top-level `or` or
// `as`, prefix_prec for a leading `-`, `+`, `!`, `~`, `&`, `*` or `<-`, and atom_prec otherwise.
fn code_prec(code string) int {
	s := code.trim_space()
	if s.starts_with('if ') || s.starts_with('match ') || s.starts_with('fn ')
		|| s.starts_with('fn(') {
		return 0
	}
	mut lowest := atom_prec
	mut depth := 0
	mut i := 0
	for i < s.len {
		c := s[i]
		if c == `'` || c == `"` || c == `\`` {
			i = skip_v_string(s, i)
			continue
		}
		if c == `(` || c == `[` || c == `{` {
			depth++
		} else if c == `)` || c == `]` || c == `}` {
			depth--
		} else if c == ` ` && depth == 0 {
			end := s.index_after(' ', i + 1) or { -1 }
			if end > i + 1 {
				p := v_prec(s[i + 1..end])
				if p >= 0 && p < lowest {
					lowest = p
				}
			}
		}
		i++
	}
	if lowest == atom_prec && (s.starts_with('-') || s.starts_with('+') || s.starts_with('!')
		|| s.starts_with('~')
		|| s.starts_with('&') || s.starts_with('*') || s.starts_with('<-')) {
		return prefix_prec
	}
	return lowest
}

// skip_v_string returns the index just past the V string literal starting at `start`,
// stepping over `${...}` interpolations, which may hold strings of their own.
fn skip_v_string(s string, start int) int {
	quote := s[start]
	mut i := start + 1
	for i < s.len {
		c := s[i]
		if c == `\\` {
			i += 2
			continue
		}
		if c == `$` && i + 1 < s.len && s[i + 1] == `{` {
			mut depth := 1
			i += 2
			for i < s.len && depth > 0 {
				d := s[i]
				if d == `'` || d == `"` || d == `\`` {
					i = skip_v_string(s, i)
					continue
				}
				if d == `{` {
					depth++
				} else if d == `}` {
					depth--
				}
				i++
			}
			continue
		}
		if c == quote {
			return i + 1
		}
		i++
	}
	return s.len
}

// as_receiver wraps emitted code that does not bind like an atom, for use before `.` or an
// index: `(s + t).to_upper()`, not `s + t.to_upper()`.
fn as_receiver(code string) string {
	return if code_prec(code) < atom_prec { '(${code})' } else { code }
}

// paren_left wraps a left operand that binds less tightly than an operator of precedence
// `prec`, and paren_right a right operand that binds less tightly or equally (V groups
// `a - b - c` as `(a - b) - c`). Both also wrap `&&` under `||` and the reverse, which V
// refuses unparenthesized ("ambiguous boolean expression").
fn paren_left(code string, prec int) string {
	p := code_prec(code)
	return if p < prec || mixes_and_or(p, prec) { '(${code})' } else { code }
}

fn paren_right(code string, prec int) string {
	p := code_prec(code)
	return if p <= prec || mixes_and_or(p, prec) { '(${code})' } else { code }
}

fn mixes_and_or(p int, prec int) bool {
	return p in [1, 2] && prec in [1, 2] && p != prec
}

// visit_binop emits V code for a binary operation (BinOp).
pub fn (mut t VTranspiler) visit_binop(node BinOp) string {
	if t.has_u64_bits(node) || t.has_u64_bits(node.left) || t.has_u64_bits(node.right) {
		if node.op is BitAnd && (t.word_bound(node.left) != none || t.word_bound(node.right) != none) {
			return '${t.unsigned_bits(*node.left, v_prec('&'))} & ${t.unsigned_bits(*node.right, v_prec('&'))}'
		}
		if (node.op is BitOr || node.op is BitXor)
			&& t.word_bound(node.left) != none && t.word_bound(node.right) != none {
			op := op_to_symbol(get_op_type(node.op))
			prec := v_prec(op)
			return '${t.unsigned_bits(*node.left, prec)} ${op} ${t.unsigned_bits(*node.right, prec)}'
		}
		if node.op is RShift && t.word_bound(node.left) != none {
			return t.unsigned_bits(node, 0)
		}
		if node.op is LShift {
			if bound := t.word_bound(node.left) {
				if count := literal_word(node.right) {
					if count < 64 && bound <= (max_unsigned_word >> int(count)) {
						return t.unsigned_bits(node, 0)
					}
				}
			}
		}
		if node.op is Mod && node.left is Constant && node.left.value is string {
			// The format uses the unsigned operand's native type.
		} else {
			return t.refuse_wide('line ${node.loc.lineno}: ${op_to_symbol(get_op_type(node.op))} has no proven result within u64')
		}
	}
	left := t.visit_expr(node.left)
	right_sink := if node.op is Mod && node.left is Constant && node.left.value is string
		&& node.left.value == '%x' {
		WideSink.hexadecimal_text
	} else {
		WideSink.unapproved
	}
	right := t.visit_expr_at(*node.right, right_sink, '')
	mut op := op_to_symbol(get_op_type(node.op))
	if node.op is Pow && t.infer_expr_type(node.left) == 'Py2vNumber'
		&& t.infer_expr_type(node.right) in ['f64', 'float'] {
		t.add_using('math')
		t.runtime_helper('numeric_as_float')
		return 'math.pow(${as_receiver(left)}.as_float(), ${right})'
	}
	if node.op is Add || node.op is Sub || node.op is Mult || node.op is Div {
		left_type := t.infer_expr_type(node.left)
		right_type := t.infer_expr_type(node.right)
		if left_type == 'Py2vNumber' || right_type == 'Py2vNumber' {
			if node.op is Div {
				t.runtime_helper('numeric_as_float')
				lhs := if left_type == 'Py2vNumber' {
					'${as_receiver(left)}.as_float()'
				} else {
					'f64(${left})'
				}
				rhs := if right_type == 'Py2vNumber' {
					'${as_receiver(right)}.as_float()'
				} else {
					'f64(${right})'
				}
				return '${t.runtime_helper('true_div')}(${lhs}, ${rhs})'
			}
			if left_type in ['f64', 'float'] || right_type in ['f64', 'float'] {
				t.runtime_helper('numeric_as_float')
				prec := v_prec(op)
				lhs := if left_type == 'Py2vNumber' {
					'${as_receiver(left)}.as_float()'
				} else {
					left
				}
				rhs := if right_type == 'Py2vNumber' {
					'${as_receiver(right)}.as_float()'
				} else {
					right
				}
				return '${paren_left(lhs, prec)} ${op} ${paren_right(rhs, prec)}'
			}
			if node.op is Sub || node.op is Add || node.op is Mult {
				lhs := t.numeric_choice_value(*node.left, left)
				rhs := t.numeric_choice_value(*node.right, right)
				t.runtime_helper('numeric_as_float')
				if node.op is Mult {
					t.require_integer_helper('mul')
					return '${t.runtime_helper('numeric_multiply')}(${lhs}, ${rhs}, ${t.integer_site(node.loc)})'
				}
				helper := if node.op is Add { 'numeric_add' } else { 'numeric_subtract' }
				return '${t.runtime_helper(helper)}(${lhs}, ${rhs})'
			}
		}
	}

	if node.op is Pow && is_zero_numeric_literal(*node.left)
		&& is_negative_numeric_literal(*node.right) {
		return t.unsupported_site('negative_zero_power', 'zero to a negative power raises a catchable Python ZeroDivisionError', '')
	}
	if node.op is LShift || node.op is RShift {
		if shift := literal_signed_integer(*node.right) {
			if shift < 0 {
				return t.unsupported_site('negative_shift_count', 'negative shifts raise a catchable Python ValueError', '')
			}
		}
	}
	if node.op !is Mod && node.left !is List && node.right !is List {
		if code := t.native_integer_binary(get_op_type(node.op), *node.left, *node.right, left,
			right, node.loc, false) {
			return code
		}
	}

	// Floating-point powers are handled separately from native integer powers.
	if node.op is Pow {
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
			t.add_using('math')
			return 'math.pow(${left}, ${right})'
		}
		return t.checked_integer('power', [left, right], node.loc)
	}

	// Handle Python % string formatting -> V string interpolation
	if node.op is Mod {
		if node.left is Constant {
			c := node.left as Constant
			if c.value is string {
				fmt_str := c.value as string
				// `str(u64)` is exact, but generic %-format folding can drop
				// a string format's precision/width. A wide source cannot
				// authorize that lossy secondary emission.
				if t.is_wide_text_source(*node.right) && fmt_str != '%s' {
					return t.refuse_wide('percent formatting of wide-derived text needs exact Python string formatting')
				}
				mut values := []string{}
				mut value_types := []string{}
				if node.right is Tuple {
					tup := node.right as Tuple
					for member in tup.elts {
						if t.is_wide_text_source(member) {
							return t.refuse_wide('tuple percent formatting of wide-derived text is unproven')
						}
					}
					if t.has_wide_args(tup.elts) {
						return t.refuse_wide('compound percent formatting of an unsigned value')
					}
					for elt in tup.elts {
						values << t.visit_expr(elt)
						value_types << t.infer_expr_type(elt)
					}
				} else {
					if t.has_u64_bits(node.right) {
						if fmt_str == '%x' { return '${as_receiver(right)}.hex()' }
						return t.refuse_wide('percent format for an unsigned value: ${fmt_str}')
					}
					values << right
					value_types << t.infer_expr_type(node.right)
				}
				return convert_percent_format(fmt_str, values, value_types)
			}
		}
		return t.modulo_expression(*node.left, *node.right, left, right, node.loc)
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
		mut left_ann := get_expr_annotation(node.left)
		mut right_ann := get_expr_annotation(node.right)
		if left_ann == '' {
			left_ann = t.infer_expr_type(node.left)
		}
		if right_ann == '' {
			right_ann = t.infer_expr_type(node.right)
		}
		nonnegative := literal_word(node.left) != none
			|| (node.left is Call && (node.left as Call).api == '__py2v__.text_length')
		if nonnegative && (literal_word(node.right) or { 0 }) > 0
			&& is_v_int_type(left_ann) && is_v_int_type(right_ann) {
			return '${paren_left(left, 5)} / ${paren_right(right, 5)}'
		}
		t.add_using('math')
		is_float := left_ann in ['f64', 'float', 'f32'] || right_ann in ['f64', 'float', 'f32']
		if is_float {
			return 'math.floor(${paren_left(left, 5)} / ${paren_right(right, 5)})'
		}
		return 'math.divide_floored(${left}, ${right}).quot'
	}

	// Handle string/list repetition
	if node.op is Mult {
		left_ann := get_expr_annotation(node.left)
		right_ann := get_expr_annotation(node.right)
		if right_ann == 'int' && (left_ann == 'string' || left_ann.starts_with('[]')) {
			if left_ann != 'string' {
				return t.list_repetition(*node.left, *node.right, left, right)
			}
			return '${as_receiver(left)}.repeat(${right})'
		}
		// Also check by inferring types when v_annotation is not set
		left_type := t.infer_expr_type(node.left)
		if left_type == 'string' {
			return '${as_receiver(left)}.repeat(${right})'
		}
		// Check if left is a List literal - list repetition
		left_expr := *node.left
		if left_expr is List {
			return t.list_repetition(left_expr, *node.right, left, right)
		}
	}

	// Handle list concatenation - V uses << operator
	if node.op is Add {
		mut la := get_expr_annotation(node.left)
		mut ra := get_expr_annotation(node.right)
		if !la.starts_with('[]') {
			la = t.infer_expr_type(node.left)
		}
		if !ra.starts_with('[]') {
			ra = t.infer_expr_type(node.right)
		}
		// A list display beside a list of known type has that type
		if !la.starts_with('[]') && node.left is List && ra.starts_with('[]') {
			la = ra
		}
		if !ra.starts_with('[]') && node.right is List && la.starts_with('[]') {
			ra = la
		}
		if la.starts_with('[]') && ra.starts_with('[]') {
			if la == ra && la in ['[]int', '[]i64', '[]f64', '[]string', '[]bool', '[]u8'] {
				t.add_using('arrays')
				return 'arrays.append(${left}, ${right})'
			}
			// An immediately called function concatenates; the operands are its
			// arguments, since either may be any expression
			return '(fn (a ${la}, b ${ra}) ${la} { mut r := a.clone(); r << b; return r }(${left}, ${right}))'
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
		// Python's / on two ints is true division; V's is integer division. A divisor
		// that can be zero goes through a helper, which stops as V's integer division does.
		left_type := t.division_operand_type(node.left, left_ann)
		right_type := t.division_operand_type(node.right, right_ann)
		if is_v_int_type(left_type) && is_v_int_type(right_type) {
			if is_nonzero_int_literal(node.right) {
				return 'f64(${left}) ${op} ${paren_right(right, v_prec(op))}'
			}
			return '${t.runtime_helper('true_div')}(${as_f64_argument(left_type, left)}, ${as_f64_argument(right_type, right)})'
		}
		// If either operand is float, ensure both are float
		if left_ann == 'int' && (right_ann == 'f64' || right_ann == 'float') {
			return 'f64(${left}) ${op} ${paren_right(right, v_prec(op))}'
		}
		if (left_ann == 'f64' || left_ann == 'float') && right_ann == 'int' {
			return '${paren_left(left, v_prec(op))} ${op} f64(${right})'
		}
		// If right is float but left annotation is unknown/empty, wrap left in f64 to be safe
		if (right_ann == 'f64' || right_ann == 'float') && left_ann == '' {
			return 'f64(${left}) ${op} ${paren_right(right, v_prec(op))}'
		}
		if (left_ann == 'f64' || left_ann == 'float') && right_ann == '' {
			return '${paren_left(left, v_prec(op))} ${op} f64(${right})'
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

	prec := v_prec(op)
	if op in ['+', '-', '*', '/'] {
		t.note_any_operator(*node.left, *node.right, left, right)
	}
	return '${paren_left(left, prec)} ${op} ${paren_right(right, prec)}'
}

fn (t VTranspiler) has_large_integer(expr Expr) bool {
	return match expr {
		Constant { (expr.kind or { '' }) == 'py2v_large_int' }
		Name { t.var_types[expr.id] == large_integer_type || t.imported_word(expr, 'large') }
		Attribute { t.imported_word(expr, 'large') }
		else { false }
	}
}

// has_u64_bits identifies a native unsigned operand, including a previously inferred name.
fn (mut t VTranspiler) has_u64_bits(expr Expr) bool {
	annotation := get_expr_annotation(expr)
	if annotation == 'c_uint64' {
		// An explicit ctypes annotation uses the existing fixed-width lowering.
		return false
	}
	if annotation == 'u64' {
		return true
	}
	return match expr {
		Constant { expr.value is u64 }
		Name { t.var_types[expr.id] == 'u64' || t.imported_word(expr, 'value') }
		Attribute { t.has_wide_member(expr, 'field') || t.imported_word(expr, 'value') }
		Call {
			if t.imported_word(expr.func, 'call') {
				true
			} else if expr.func is Name {
				t.func_return_types[expr.func.id] == 'u64'
					|| (t.var_types[expr.func.id].starts_with('fn (')
						&& t.var_types[expr.func.id].ends_with(') u64'))
			} else {
				expr.func is Attribute && t.has_wide_member(expr.func, 'method')
			}
		}
		Subscript {
			typ := t.infer_expr_type(expr.value)
			typ == '[]u64' || (typ.starts_with('map[') && typ.ends_with(']u64'))
		}
		BinOp {
			if expr.op is LShift {
				if count := literal_word(*expr.right) {
					if left := literal_shift_word(*expr.left) {
						if left != 0 && (count >= 63 || left > (u64(0x7fffffffffffffff) >> int(count))) {
							return true
						}
					}
				}
				t.has_u64_bits(*expr.left)
			} else if expr.op is RShift {
				t.has_u64_bits(*expr.left)
			} else {
				(expr.op is BitAnd || expr.op is BitOr || expr.op is BitXor)
					&& (t.has_u64_bits(*expr.left) || t.has_u64_bits(*expr.right))
			}
		}
		else { false }
	}
}

fn (mut t VTranspiler) has_wide_member(expr Attribute, kind string) bool {
	if t.registry.wide_exports.len > 0 {
		owner := expr_class_path(expr.value)
		if owner != '' && t.registry.wide_exports['${kind}:${owner}.${expr.attr}'] {
			return true
		}
	}
	if t.wide_members.len == 0 && t.registry.wide_members.len == 0 {
		return false
	}
	owner := if expr.value is Name && expr.value.id == 'self' {
		emitted_class_name(t.current_class_name)
	} else {
		t.infer_expr_type(expr.value).trim_left('?&')
	}
	if t.wide_members['${kind}:${owner}.${expr.attr}'] {
		return true
	}
	if owner == '' { return false }
	if path := t.init_import_aliases[owner] {
		if t.registry.wide_exports['${kind}:${path}.${expr.attr}'] {
			return true
		}
	}
	qualified := if owner.contains('.') { owner } else { '${t.module_name}.${owner}' }
	return t.registry.wide_members['${kind}:${qualified}.${expr.attr}']
}

fn (mut t VTranspiler) has_wide_destination(target Expr) bool {
	return match target {
		Name { t.var_types[target.id] in ['u64', large_integer_type] }
		Attribute { t.has_u64_bits(target) }
		Tuple, List { target.elts.any(t.has_wide_destination(it)) }
		Starred { t.has_wide_destination(target.value) }
		else { false }
	}
}

fn is_wide_container_type(typ string) bool {
	return (typ.starts_with('[]') || typ.starts_with('map[') || typ.starts_with('&pyrt.ListRef[')
		|| typ.starts_with('?')) && 'u64' in typ.split_any('[]? ')
}

fn (mut t VTranspiler) has_wide_container_type(expr Expr) bool {
	if expr is Name && is_wide_container_type(t.var_types[expr.id]) {
		return true
	}
	if expr is Call && expr.func is Name && is_wide_container_type(t.func_return_types[expr.func.id]) {
		return true
	}
	annotation := get_expr_annotation(expr)
	return annotation.contains('u64') && is_wide_container_type(t.map_type(annotation))
}

const max_unsigned_word = u64(0xffffffffffffffff)

// refuse_wide leaves the expression visible to V's checker.
fn (mut t VTranspiler) refuse_wide(reason string) string {
	return t.unsupported_site('wide_integer', reason, '')
}

fn (mut t VTranspiler) unsupported_site(kind string, reason string, operand string) string {
	base := 'py2v_unsupported_${kind}'
	symbol := if base in t.source_words || base in t.registry.module_words[t.module_name] {
		t.runtime_helper_name('unsupported_${kind}')
	} else {
		base
	}
	call := "${symbol}('${escape_string(reason)}')"
	t.unsupported_sites[symbol] = call
	if operand != '' {
		return "${symbol}(${operand}, '${escape_string(reason)}')"
	}
	return call
}

// keep_unsupported_checks preserves a checker error if package lowering omits
// an executable module-level statement that contained the original call.
fn (mut t VTranspiler) keep_unsupported_checks(code string) string {
	if t.unsupported_sites.len == 0 {
		return code
	}
	lines := code.split_into_lines()
	mut guards := []string{}
	for symbol, call in t.unsupported_sites {
		if lines.any(!it.trim_space().starts_with('//') && it.contains(symbol + '(')) {
			continue
		}
		kind := symbol.trim_string_left('py2v_') + '_guard'
		key := '${t.module_name}.${kind}'
		if !t.registry.helper_declared[key] {
			t.registry.helper_declared[key] = true
			guards << 'const ${t.runtime_helper_name(kind)} = ${call}'
		}
	}
	return if guards.len == 0 { code } else { code + '\n\n' + guards.join('\n') }
}

// literal_word recognizes a nonnegative integer literal.
fn literal_word(expr Expr) ?u64 {
	if expr is Constant {
		return match expr.value {
			u64 { expr.value }
			i64 {
				if expr.value >= 0 { u64(expr.value) } else { none }
			}
			int {
				if expr.value >= 0 { u64(expr.value) } else { none }
			}
			else { none }
		}
	}
	return none
}

fn literal_shift_word(expr Expr) ?u64 {
	if expr is BinOp && expr.op is LShift {
		left := literal_shift_word(*expr.left) or { return none }
		count := literal_word(*expr.right) or { return none }
		if count < 64 && left <= (max_unsigned_word >> int(count)) {
			return left << int(count)
		}
		return none
	}
	return literal_word(expr)
}

// word_bound supplies a native bound for an unsigned value or a masked expression.
fn (mut t VTranspiler) word_bound(expr Expr) ?u64 {
	if bound := literal_word(expr) {
		return bound
	}
	if expr is BinOp {
		if expr.op is BitAnd {
			left := t.word_bound(expr.left)
			right := t.word_bound(expr.right)
			if l := left {
				r := right or { return l }
				return if l <= r { l } else { r }
			}
			return right
		}
		if expr.op is LShift || expr.op is RShift || expr.op is BitOr || expr.op is BitXor {
			left := t.word_bound(expr.left) or { return none }
			if expr.op is RShift {
				return left
			}
			if expr.op is LShift {
				count := literal_word(expr.right) or { return none }
				if count < 64 && left <= (max_unsigned_word >> int(count)) {
					return left << int(count)
				}
			} else if t.word_bound(expr.right) != none {
				return max_unsigned_word
			}
		}
		return none
	}
	if expr is UnaryOp {
		return if expr.op is UAdd { t.word_bound(expr.operand) } else { none }
	}
	return if t.has_u64_bits(expr) { max_unsigned_word } else { none }
}

// nonnegative_wide_compare_operand preserves a constant left shift that fits u64,
// rather than passing its signed-V spelling through i64 (where bit 63 is negative).
fn (mut t VTranspiler) nonnegative_wide_compare_operand(expr Expr) ?string {
	bound := t.word_bound(expr) or { return none }
	if bound <= u64(0x7fffffffffffffff) { return none }
	if expr is BinOp && expr.op is LShift && t.word_bound(expr.left) != none
		&& literal_word(expr.right) != none {
		return t.unsigned_bits(expr, 0)
	}
	return none
}

// has_wide_args finds a wide value in a flat argument list.
fn (mut t VTranspiler) has_wide_args(args []Expr) bool {
	for arg in args {
		if t.has_u64_bits(arg) {
			return true
		}
	}
	return false
}

// unsigned_bits computes the low 64 bits for an already-proven mask. A left shift must widen
// its operand before shifting, and a masked complement needs only those bits.
fn (mut t VTranspiler) unsigned_bits(expr Expr, prec int) string {
	if expr is BinOp && (expr.op is LShift || expr.op is RShift) {
		if expr.op is RShift && t.word_bound(expr.left) == none {
			return t.refuse_wide('right shift before masking may need bits outside u64')
		}
		op := op_to_symbol(get_op_type(expr.op))
		left := t.unsigned_bits(*expr.left, v_prec(op))
		right := t.visit_expr(expr.right)
		if expr.right is Constant && expr.right.value is int && expr.right.value >= 0
			&& expr.right.value < 64 {
			return '(${left} ${op} ${right})'
		}
		helper := if expr.op is LShift { 'shift_left_u64' } else { 'shift_right_u64' }
		return '${t.runtime_helper(helper)}(${left}, ${right})'
	}
	if expr is UnaryOp && expr.op is Invert {
		return '~${t.unsigned_bits(*expr.operand, prefix_prec)}'
	}
	if expr is UnaryOp && expr.op is USub {
		return '(u64(0) - ${t.unsigned_bits(*expr.operand, v_prec('-'))})'
	}
	if expr is BinOp && (expr.op is Add || expr.op is Sub || expr.op is Mult) {
		op := op_to_symbol(get_op_type(expr.op))
		left := t.unsigned_bits(*expr.left, v_prec(op))
		right := t.unsigned_bits(*expr.right, v_prec(op))
		return '(${left} ${op} ${right})'
	}
	code := t.visit_expr_at(expr, .bounded_bits, '')
	if t.has_u64_bits(expr) {
		return paren_right(code, prec)
	}
	if t.infer_expr_type(expr) in ['string', 'f32', 'f64'] {
		return t.refuse_wide('masking needs an integer operand')
	}
	return 'u64(${code})'
}

// unsigned_bit_function names a V bit helper with the native unsigned signature.
fn (mut t VTranspiler) unsigned_bit_function(method string) string {
	bits_module := t.runtime_helper_name('math_bits')
	t.add_using('math.bits as ${bits_module}')
	member := if method == 'bit_length' { 'len_64' } else { 'ones_count_64' }
	return '${bits_module}.${member}'
}

// integer_boundary reconciles native widths when a declared type requires it.
fn (mut t VTranspiler) integer_boundary(expr Expr, code string, typ string) string {
	if typ in ['i8', 'i16', 'i32', 'u8', 'u16', 'u32'] {
		if t.has_u64_bits(expr) {
			return t.refuse_wide('unsigned conversion to ${typ} is unsupported')
		}
		from := t.infer_expr_type(expr)
		if from != typ && native_integer_type(from) {
			return '${typ}(${code})'
		}
		return code
	}
	if typ == 'f64' {
		if t.has_u64_bits(expr) {
			return t.refuse_wide('conversion of an unsigned value at a float annotation')
		}
		// A wide literal can cross the existing float boundary if no digits are lost.
		literal := if expr is UnaryOp && (expr.op is UAdd || expr.op is USub) {
			*expr.operand
		} else {
			expr
		}
		if literal is Constant {
			value := literal.value
			limit := i64(1) << 53
			if value is i64 && value >= -limit && value <= limit {
				return 'f64(${code})'
			}
		}
	}
	if typ !in ['u64', 'int', 'i64'] {
		return code
	}
	unsigned := t.has_u64_bits(expr)
	if typ == 'u64' && !unsigned {
		if t.word_bound(expr) == none {
			return t.refuse_wide('conversion to u64 needs a nonnegative value with a proven bound')
		}
		if expr is BinOp {
			return t.unsigned_bits(expr, 0)
		}
		return 'u64(${code})'
	}
	if typ in ['int', 'i64'] && unsigned {
		return t.refuse_wide('unsigned conversion to ${typ} is unsupported')
	}
	return code
}

// visit_unaryop emits V code for a unary operation (UnaryOp).
pub fn (mut t VTranspiler) visit_unaryop(node UnaryOp) string {
	if (node.op is USub || node.op is Invert) && t.has_u64_bits(node.operand) {
		return t.refuse_wide('line ${node.loc.lineno}: unary ${op_to_symbol(get_unary_op_type(node.op))} needs an enclosing mask')
	}
	op := op_to_symbol(get_unary_op_type(node.op))
	operand := t.visit_expr(node.operand)
	if node.op is USub {
		typ := t.infer_expr_type(*node.operand)
		if native_integer_type(typ) && typ !in ['int', 'i64'] {
			return '-int(${operand})'
		}
	}
	// A prefix binds tighter than any binary operator, so an operand that binds less tightly
	// than a prefix is wrapped (`-(a + b)`, `!(a == b)`, `+(a > b)`), as is every BinOp and,
	// under `not`, every comparison and boolean operation, as before. `- -x` would read as
	// `--x`, so a sign before the same sign is wrapped too.
	if node.operand is BinOp || code_prec(operand) < prefix_prec
		|| (node.op is Not && (node.operand is Compare || node.operand is BoolOp))
		|| (op in ['-', '+'] && operand.starts_with(op)) {
		return '${op}(${operand})'
	}
	return '${op}${operand}'
}

// visit_boolop emits V code for a boolean operation (BoolOp).
pub fn (mut t VTranspiler) visit_boolop(node BoolOp) string {
	op := op_to_symbol(get_bool_op_type(node.op))
	own := v_prec(op)
	mut parts := []string{}
	for val in node.values {
		expr_str := t.visit_expr(val)
		p := code_prec(expr_str)
		// Wrap nested BoolOps, and any operand that binds less tightly than `op` or would put
		// `&&` beside `||` (`p and (q | r)` on bools), which V refuses.
		if val is BoolOp || p < own || mixes_and_or(p, own) {
			parts << '(${expr_str})'
		} else {
			parts << expr_str
		}
	}
	return parts.join(' ${op} ')
}

// visit_compare emits V code for comparison expressions (Compare).
pub fn (mut t VTranspiler) visit_compare(node Compare) string {
	if node.ops.len > 1 && node.comparators.len == node.ops.len {
		return t.visit_compare_chain(node)
	}
	sink := if !node.truth_test && node.ops.len > 0
		&& get_cmp_op_type(node.ops[0]) in ['Eq', 'NotEq', 'Lt', 'LtE', 'Gt', 'GtE'] {
		WideSink.integer_comparison
	} else {
		WideSink.unapproved
	}
	left := t.visit_expr_at(*node.left, sink, '')

	if node.ops.len > 0 && node.ops[0] is In {
		// Check if right side is dict.values() - use .keys().map() for V compatibility
		comp := node.comparators[0]
		if comp is Call {
			cc := comp as Call
			if cc.func is Attribute {
				attr := cc.func as Attribute
				if attr.attr == 'values' {
					dict_obj := t.visit_expr(attr.value)
					return '${cmp_operand(left)} in ${as_receiver(dict_obj)}.keys().map(${as_receiver(dict_obj)}[it])'
				}
			}
		}
		right := t.visit_expr(comp)
		// Check if right side is a string - use .contains() instead of 'in'
		right_ann := get_expr_annotation(comp)
		right_type := if right_ann.len > 0 { right_ann } else { t.infer_expr_type(comp) }
		if right_type == 'string' {
			return '${as_receiver(right)}.contains(${left})'
		}
		// Parenthesised because V binds `=` more tightly than `in`, so an
		// unparenthesised `x = a in b` parses as `(x = a) in b` and fails.
		return '(${cmp_operand(left)} in ${cmp_operand(right)})'
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
			return '!${as_receiver(right)}.contains(${left})'
		}
		return '(${cmp_operand(left)} !in ${cmp_operand(right)})'
	}

	op := op_to_symbol(get_cmp_op_type(node.ops[0]))
	mut right := t.visit_expr_at(node.comparators[0], sink, '')
	if op in ['==', '!=', '<', '<=', '>', '>='] {
		lt := t.infer_expr_type(node.left)
		rt := t.infer_expr_type(node.comparators[0])
		if lt == 'Py2vNumber' && rt in ['f64', 'float'] {
			return t.numeric_float_comparison(left, right, op, false)
		}
		if lt == 'Py2vNumber' && rt in ['int', 'i64'] && !is_zero_numeric_literal(node.comparators[0]) {
			return t.numeric_int_comparison(left, right, op)
		}
		if lt == 'Py2vNumber' {
			if n := literal_signed_integer(node.comparators[0]) {
				if n == 0 { return t.numeric_float_comparison(left, '0.0', op, false) }
			}
		}
		if rt == 'Py2vNumber' && lt in ['f64', 'float'] {
			return t.numeric_float_comparison(left, right, reverse_comparison(op), true)
		}
		if rt == 'Py2vNumber' && lt in ['int', 'i64'] {
			return t.numeric_int_comparison(right, left, reverse_comparison(op))
		}
	}
	if op in ['==', '!='] {
		text := if right == 'none' && t.is_plain_text_parameter(node.left) {
			left
		} else if left == 'none' && t.is_plain_text_parameter(node.comparators[0]) {
			right
		} else {
			''
		}
		if text != '' {
			negation := if op == '!=' { '!' } else { '' }
			return '${negation}${t.runtime_helper('text_is_none')}(${text})'
		}
	}
	if op in ['==', '!=', '<', '<=', '>', '>='] {
		cmp := node.comparators[0]
		left_wide := t.has_u64_bits(node.left)
		right_wide := t.has_u64_bits(cmp)
		if left_wide && !right_wide && t.infer_expr_type(cmp) in ['int', 'i64'] {
			if native := t.nonnegative_wide_compare_operand(cmp) {
				return '${cmp_operand(left)} ${op} ${cmp_operand(native)}'
			}
			if cmp is BinOp || (cmp is UnaryOp && (cmp as UnaryOp).operand is BinOp) {
				return t.refuse_wide('signed comparison operand has no proven i64 bound')
			}
			return '${t.runtime_helper('cmp_u64_int')}(${left}, i64(${right})) ${op} 0'
		}
		if right_wide && !left_wide && t.infer_expr_type(node.left) in ['int', 'i64'] {
			if native := t.nonnegative_wide_compare_operand(node.left) {
				return '${cmp_operand(native)} ${op} ${cmp_operand(right)}'
			}
			if node.left is BinOp || (node.left is UnaryOp && (node.left as UnaryOp).operand is BinOp) {
				return t.refuse_wide('signed comparison operand has no proven i64 bound')
			}
			return '${t.runtime_helper('cmp_int_u64')}(i64(${left}), ${right}) ${op} 0'
		}
		if left_wide != right_wide {
			return t.refuse_wide('comparison of an unsigned value needs a native integer operand')
		}
	}

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
			return '0 ${op} ${cmp_operand(right)}'
		}
	}

	if op in ['<', '<=', '>', '>='] {
		t.note_any_operator(*node.left, node.comparators[0], left, right)
	}
	return '${cmp_operand(left)} ${op} ${cmp_operand(right)}'
}

fn (t &VTranspiler) is_plain_text_parameter(expr Expr) bool {
	return expr is Name && expr.id in t.param_idents && !t.param_idents[expr.id]
		&& t.var_types[expr.id] == 'string'
}

// visit_compare_chain emits `a < b <= c` as `a < b && b <= c`: one comparison for each
// operator, joined with `&&`, which stops at the first false one as Python does. A middle
// operand is written twice, so it is evaluated twice when it is not a plain value;
// bind_chain_middle binds it to a temporary first where the statement allows it.
fn (mut t VTranspiler) visit_compare_chain(node Compare) string {
	mut parts := []string{cap: node.ops.len}
	for i, op in node.ops {
		left := if i == 0 { *node.left } else { node.comparators[i - 1] }
		parts << t.visit_expr(Compare{
			left:        &left
			ops:         [op]
			comparators: [node.comparators[i]]
			loc:         node.loc
		})
	}
	return join_conditions(parts, '&&')
}

// chain_operand_is_plain reports an operand that can be written twice: a name, a constant,
// an attribute or subscript of those, arithmetic on them, or `len`/`abs` of them.
fn chain_operand_is_plain(e Expr) bool {
	return match e {
		Name, Constant {
			true
		}
		Attribute {
			chain_operand_is_plain(*e.value)
		}
		Subscript {
			chain_operand_is_plain(*e.value) && chain_operand_is_plain(*e.slice)
		}
		UnaryOp {
			chain_operand_is_plain(*e.operand)
		}
		BinOp {
			chain_operand_is_plain(*e.left) && chain_operand_is_plain(*e.right)
		}
		Call {
			e.func is Name && (e.func as Name).id in ['len', 'abs'] && e.keywords.len == 0
				&& e.args.all(chain_operand_is_plain(it))
		}
		else {
			false
		}
	}
}

// bind_chain_middle handles a chained comparison that is the whole value of a statement
// and whose first middle operand is not a plain value (`0 < f() < 5`): it declares a
// temporary holding that operand in `prelude` and returns the comparison on the temporary,
// so the operand is evaluated once. Python evaluates the left operand first, so this is
// done only when the left operand is plain; later middle operands are evaluated only
// when the comparisons before them hold, so they are never bound ahead.
fn (mut t VTranspiler) bind_chain_middle(e Expr, mut prelude []string) Expr {
	if e !is Compare {
		return e
	}
	node := e as Compare
	if node.ops.len < 2 || node.comparators.len != node.ops.len
		|| !chain_operand_is_plain(*node.left) || chain_operand_is_plain(node.comparators[0]) {
		return e
	}
	tmp := t.new_tmp('cmp')
	inferred := t.infer_expr_type(node.comparators[0])
	if inferred.len > 0 {
		t.var_types[tmp] = inferred
	}
	prelude << '${tmp} := ${t.visit_expr(node.comparators[0])}'
	mut comparators := node.comparators.clone()
	comparators[0] = Expr(Name{
		id:  tmp
		loc: node.loc
	})
	return Expr(Compare{
		...node
		comparators: comparators
	})
}

// cmp_operand wraps an operand of a comparison that binds at a comparison's level or lower:
// `(a < b) == c`, `(q && r) == q`.
fn cmp_operand(code string) string {
	return if code_prec(code) <= v_prec('==') { '(${code})' } else { code }
}

// join_conditions joins match conditions with `&&` or `||`, wrapping a condition that binds
// less tightly or would put `&&` beside `||` (`case [1 | 2]`).
fn join_conditions(parts []string, op string) string {
	own := v_prec(op)
	mut out := []string{cap: parts.len}
	for part in parts {
		p := code_prec(part)
		out << if p < own || mixes_and_or(p, own) { '(${part})' } else { part }
	}
	return out.join(' ${op} ')
}

// Names the builtin dispatch handles on their original arguments.
const call_dispatch_names = ['range', 'print', 'bool', 'int', 'float', 'str', 'len', 'min', 'max',
	'abs', 'round', 'floor', 'pow', 'sum', 'sorted', 'map', 'filter', 'all', 'any', 'enumerate',
	'zip', 'open', 'input', 'type', 'id', 'getattr', 'setattr', 'hasattr', 'isinstance', 'list',
	'tuple', 'set', 'dict', 'divmod', 'ord', 'chr', 'reversed', 'Path']!

struct BindingCall {
	call        Call
	in_function bool
}

fn count_call_bindings[T](node T, mut names map[string]int, mut calls []BindingCall, in_function bool) {
	mut exceptions := map[string][]string{}
	collect_module_info(node, mut names, mut calls, mut exceptions, in_function)
}

// Collect bindings, calls, and errors, keeping definition-time expressions at module scope.
fn collect_module_info[T](node T, mut names map[string]int, mut calls []BindingCall, mut exceptions map[string][]string, in_function bool) {
	$if T is Call {
		calls << BindingCall{node, in_function}
		if node.api == '__py2v__.checked_list_index' {
			exceptions['IndexError'] = ['LookupError', 'Exception', 'BaseException']
		} else if node.api.starts_with('__py2v__.checked_') && node.api != '__py2v__.checked_text_index' {
			exceptions['ZeroDivisionError'] = ['ArithmeticError', 'Exception', 'BaseException']
		} else if node.api.starts_with('__py2v__.native_value_error_') {
			exceptions['ValueError'] = ['Exception', 'BaseException']
		}
	}
	$if T is Raise {
		if node.mode in ['native_guard', 'native_result'] {
			name := raised_name(node)
			if name != '' {
				exceptions[name] = node.bases
			}
		}
	}
	$if T is Name {
		if node.ctx !is Load {
			names[node.id]++
		} else if ':load:' in names {
			names[':load:${node.id}']++
		}
	} $else $if T is Arg {
		names[node.arg]++
	} $else $if T is FunctionDef || T is AsyncFunctionDef || T is ClassDef {
		names[node.name]++
	} $else $if T is Alias {
		names[node.asname or { node.name.all_before('.') }]++
	} $else $if T is ExceptHandler || T is MatchAs || T is MatchStar {
		if name := node.name { names[name]++ }
	} $else $if T is MatchMapping {
		if name := node.rest { names[name]++ }
	}
	$if T is $option {
		if value := node {
			collect_module_info(value, mut names, mut calls, mut exceptions, in_function)
		}
	} $else $if T is $pointer {
		collect_module_info(*node, mut names, mut calls, mut exceptions, in_function)
	} $else $if T is $array {
		for value in node {
			collect_module_info(value, mut names, mut calls, mut exceptions, in_function)
		}
	} $else $if T is $sumtype {
		$for variant in T.variants {
			if node is variant {
				collect_module_info(node, mut names, mut calls, mut exceptions, in_function)
			}
		}
	} $else $if T is Raise {
		if exc := node.exc {
			if exc is Call && exc.func is Name
				&& node.mode in ['result', 'guard', 'native_result', 'native_guard'] {
				// The raise emitter constructs an error directly, but still visits its arguments.
				collect_module_info[[]Expr](exc.args, mut names, mut calls, mut exceptions, in_function)
			} else {
				collect_module_info[&Expr](exc, mut names, mut calls, mut exceptions, in_function)
			}
		}
		collect_module_info[?&Expr](node.cause, mut names, mut calls, mut exceptions, in_function)
	} $else $if T is $struct {
		$for field in T.fields {
			mut body := in_function
			$if T is FunctionDef || T is AsyncFunctionDef || T is Lambda {
				if field.name == 'body' { body = true }
			}
			$if T is FunctionDef {
				// The frontend turns `if __name__ == "__main__":` into `def main()`; its body still runs at module level.
				if field.name == 'body' && node.name == 'main' && node.args.args.len == 0
					&& node.returns == none {
					body = in_function
				}
			}
			collect_module_info(node.$(field.name), mut names, mut calls, mut exceptions, body)
		}
	}
}

fn call_literal_default(expr Expr) bool {
	if expr is Constant {
		return expr.value !is BytesValue && expr.value !is EllipsisValue
	}
	if expr is UnaryOp && expr.op is USub && expr.operand is Constant {
		value := (expr.operand as Constant).value
		return value is int || value is i64 || value is f64 || value is ComplexValue
	}
	return false
}

fn (t &VTranspiler) bind_module_call(node Call, allow_local_results bool) ?Call {
	if node.func !is Name { return none }
	if t.call_before_def[node.loc.str()] { return none }
	allow_local_result := allow_local_results && node.keywords.len > 0
	name := (node.func as Name).id
	sig := t.call_signatures[name] or {
		// A different call may have canceled binding across the module. The local result
		// signature still proves the parameter order for this call.
		if !allow_local_result { return none }
		known := t.module_safe_signatures[name] or { return none }
		if !known.raises { return none }
		known
	}
	if sig.args.posonlyargs.len > 0 || sig.args.vararg != none || sig.args.kwarg != none
		|| node.args.len > sig.args.args.len || sig.is_generator {
		return none
	}
	mut params := sig.args.args.clone()
	params << sig.args.kwonlyargs
	for param in params {
		if param.arg in ['self', 'cls'] { return none }
		// A rebound number, string or bool parameter is copied inside the function, so
		// the caller passes it like any other; other mutable parameters need `mut`.
		if param.arg in sig.mutable_vars && !is_value_param(param) { return none }
	}
	mut defaults := map[string]Expr{}
	for i, expr in sig.args.defaults {
		defaults[params[sig.args.args.len - sig.args.defaults.len + i].arg] = expr
	}
	for i, expr in sig.args.kw_defaults {
		if value := expr { defaults[sig.args.kwonlyargs[i].arg] = value }
	}
	mut supplied := map[string]Expr{}
	mut order := []string{}
	for i, expr in node.args {
		if expr is Starred { return none }
		param := params[i].arg
		supplied[param] = expr
		order << param
	}
	for kw in node.keywords {
		param := kw.arg or { return none }
		if param !in params.map(it.arg) || param in supplied { return none }
		supplied[param] = kw.value
		order << param
	}
	mut reorder_safe := true
	for expr in supplied.values() {
		if !(expr is Constant || expr is Name
			|| (expr is UnaryOp && expr.op is USub && expr.operand is Constant)) {
			reorder_safe = false
		}
	}
	mut bound := []Expr{}
	mut position := 0
	for param in params {
		if expr := supplied[param.arg] {
			if order[position] != param.arg && !reorder_safe {
				return none
			}
			position++
			bound << expr
		} else {
			expr := defaults[param.arg] or { return none }
			if !call_literal_default(expr) {
				if !allow_local_result || !sig.raises || expr !is Name { return none }
				// The frontend excludes shadowed and rebound module constants. Require an
				// earlier scalar initializer so the name denotes the definition-time value.
				line := t.module_scalar_defaults[expr.id] or { return none }
				if line >= sig.loc.lineno { return none }
			}
			bound << expr
		}
	}
	return Call{ ...node, args: bound, keywords: []Keyword{} }
}

// Preserve Python evaluation order for a proven same-order local call even when
// another unrelated call made the broader keyword binder cancel its analysis.
// All parameters must be supplied in their declaration order; otherwise a
// reordered effectful expression cannot be rendered as V positional arguments.
fn (t &VTranspiler) bind_source_order_call(node Call) ?Call {
	if node.func !is Name || node.keywords.len == 0
		|| t.call_before_def[node.loc.str()] {
		return none
	}
	name := (node.func as Name).id
	sig := t.module_safe_signatures[name] or { return none }
	if sig.args.posonlyargs.len > 0 || sig.args.vararg != none
		|| sig.args.kwarg != none || sig.is_generator {
		return none
	}
	mut params := sig.args.args.clone()
	params << sig.args.kwonlyargs
	if params.len != node.args.len + node.keywords.len
		|| node.args.len > sig.args.args.len {
		return none
	}
	for argument in node.args {
		if argument is Starred { return none }
	}
	for param in params {
		if param.arg in ['self', 'cls'] { return none }
	}
	mut bound := node.args.clone()
	for i, kw in node.keywords {
		kw_name := kw.arg or { return none }
		if kw_name != params[node.args.len + i].arg { return none }
		bound << kw.value
	}
	return Call{ ...node, args: bound, keywords: []Keyword{} }
}

// guarded_call turns the text of a call that ends the program on an error into one that
// hands the error to the handlers of `try` number `n` and leaves the try body.
fn (t &VTranspiler) guarded_call(code string, n int, local_method bool) string {
	leave := ' or {\n\tpy2v_err_${n} = err\n\tbreak py2v_try_${n}\n}'
	passed := t.propagated_call(code, local_method)
	if passed.ends_with('!') && passed != code {
		return passed[..passed.len - 1] + leave
	}
	return code
}

// propagated_call turns the text of a call that ends the program on an error into one
// that passes the error on: `f(x) or { pyrt.fail(err) }` becomes `f(x)!`, and a call of a
// function of this file `g(x)` becomes `g_py(x)!` (the frontend marks only calls of
// functions it made fallible). Any other text is returned as it is.
fn (t &VTranspiler) propagated_call(code string, local_method bool) string {
	suffix := ' or { pyrt.fail(err) }'
	if code.starts_with('(') && code.ends_with(suffix + ')') {
		return code[1..code.len - suffix.len - 1] + '!'
	}
	if code.ends_with(suffix) {
		return code[..code.len - suffix.len] + '!'
	}
	open := code.index('(') or { return code }
	mut name := code[..open]
	if name in t.unsupported_sites || name.len == 0 || !code.ends_with(')')
		|| name.contains_any(' \n{}[]=')
		|| (!local_method && name.contains('.')) {
		return code
	}
	if local_method {
		parts := name.split('.')
		if !parts.all(is_simple_identifier(it) || (it.starts_with('@') && is_simple_identifier(it[1..]))) {
			return code
		}
		// The emitted escape on a keyword method is not part of its suffixed name.
		method := parts.last()
		if method.starts_with('@') {
			name = name[..name.len - method.len] + method[1..]
		}
	}
	return '${name}_py${code[open..]}!'
}

// runtime_dispatched_methods are the methods of str, list, dict and set that a value of
// unknown type is most often asked for.
const runtime_dispatched_methods = ['get', 'items', 'keys', 'values', 'setdefault', 'update', 'pop',
	'copy', 'append', 'extend', 'insert', 'remove', 'sort', 'reverse', 'index', 'count', 'add',
	'discard', 'strip', 'lstrip', 'rstrip', 'lower', 'upper', 'title', 'split', 'splitlines',
	'startswith', 'endswith', 'replace', 'find', 'encode', 'decode', 'isdigit']!

// without_opt takes the `.opt()` that ends the text of a runtime call giving a
// `pyrt.Maybe`, so that the error handling of the call itself can be rewritten.
fn without_opt(code string) (string, bool) {
	if code.ends_with('.opt()') {
		return code[..code.len - 6], true
	}
	return code, false
}

fn (mut t VTranspiler) visit_checked_operation(node Call) string {
	kind := node.api.all_after('__py2v__.')
	helper := t.runtime_helper(kind)
	mut args := node.args.map(t.visit_expr(it))
	if kind in ['checked_true_div', 'checked_float_floor_div', 'checked_float_mod'] {
		args[0] = 'f64(${args[0]})'
		args[1] = 'f64(${args[1]})'
	}
	if kind !in ['checked_true_div', 'checked_list_index'] {
		t.add_using('math')
	}
	call := '${helper}(${args.join(', ')})'
	guard := if node.guard > 0 { node.guard } else { t.active_error_guard }
	if guard > 0 {
		return '${call} or {\n\tpy2v_err_${guard} = err\n\tbreak py2v_try_${guard}\n}'
	}
	return '${call} or { ${t.escape_exception('err')} }'
}

// visit_call binds eligible module functions before rendering their arguments.
pub fn (mut t VTranspiler) visit_call(original Call) string {
	return t.visit_expr(original)
}

fn (mut t VTranspiler) visit_call_at(original Call, permit WideSink, permit_type string) string {
	// A literal Python format string must not silently lose the width,
	// precision, conversion, or alignment of wide-derived decimal text.
	if original.func is Attribute && original.func.attr == 'format'
		&& original.func.value is Constant {
		format_source := original.func.value as Constant
		if format_source.value is string && (format_source.value as string) != '{}' {
			for argument in original.args {
				if t.is_wide_text_source(argument) {
					return t.refuse_wide('formatting wide-derived text needs exact Python field handling')
				}
			}
		}
	}
	if original.api == '__py2v__.unsupported_keyword_evaluation_order' {
		return t.unsupported_site('keyword_argument_order', 'keyword values have unproven evaluation order', '')
	}
	if original.api == '__py2v__.unsupported_set_iteration' {
		return t.unsupported_site('set_iteration', 'native set iteration cannot preserve CPython order', '')
	}
	if original.api == '__py2v__.unsupported_unicode_surrogate' && original.args.len == 1
		&& original.args[0] is Constant && (original.args[0] as Constant).value is string {
		reason := (original.args[0] as Constant).value as string
		return t.unsupported_site('unicode_surrogate', reason, '')
	}
	if original.api == '__py2v__.unsupported_annotated_call' && original.args.len == 2
		&& original.args[1] is Constant && (original.args[1] as Constant).value is string {
		reason := (original.args[1] as Constant).value as string
		value := t.visit_expr(original.args[0])
		return t.unsupported_site('annotated_call', reason, value)
	}
	if original.api == '__py2v__.text_length' && original.args.len == 1 {
		return '${as_receiver(t.visit_expr(original.args[0]))}.len_utf8()'
	}
	if original.func is Name && original.func.id == 'len' && original.args.len == 1
		&& original.keywords.len == 0 && original.func.id !in t.module_functions
		&& !t.is_bound_in_scope(original.func.id) && original.args[0] is ListComp {
		comp := original.args[0] as ListComp
		if comp.generators.len == 1 && comp.elt is Name {
			gen := comp.generators[0]
			if gen.target is Name && (comp.elt as Name).id == (gen.target as Name).id
				&& gen.iter is List && gen.ifs.len > 0 && !gen.is_async
				&& t.infer_expr_type(gen.iter) in ['[]int', '[]i64', '[]f64', '[]string', '[]bool',
					'[]u8']
				&& !gen.ifs.any(has_walrus_in_expr(it)) {
				return t.visit_generator_exp_impl(comp.elt, comp.generators, true)
			}
		}
	}
	if original.api == '__py2v__.text_characters' && original.args.len == 1 {
		return '${as_receiver(t.visit_expr(original.args[0]))}.runes().map(it.str())'
	}
	// A proven u64 is not a pyrt.Value: implicit V union conversion loses
	// the high bit and even renders some values as the empty string. Plain V
	// string conversion is exact and needs no runtime or boxing.
	if original.func is Attribute && original.args.len == 1 && original.keywords.len == 0 {
		func := original.func as Attribute
		if func.attr == 'type_name' && func.value is Name
			&& (func.value as Name).id == 'pyrt'
			&& t.infer_expr_type(original.args[0]) == 'Py2vNumber' {
			return '${t.runtime_helper('numeric_type_name')}(${t.visit_expr(original.args[0])})'
		}
		if func.attr in ['str', 'repr'] && func.value is Name
			&& (func.value as Name).id == 'pyrt' {
			if t.infer_expr_type(original.args[0]) == 'Py2vNumber' {
				return '${as_receiver(t.visit_expr(original.args[0]))}.str()'
			}
			if t.has_u64_bits(original.args[0]) || t.has_large_integer(original.args[0]) {
				return '${as_receiver(t.visit_expr_at(original.args[0], .decimal_text, ''))}.str()'
			}
		}
	}
	if original.func is Attribute && original.args.len == 0 && original.keywords.len == 0
		&& original.func.attr in ['bit_length', 'bit_count'] && t.has_u64_bits(original.func.value) {
		value := t.visit_expr_at(*original.func.value, .bit_measure, '')
		return '${t.unsigned_bit_function(original.func.attr)}(${value})'
	}
	if original.api.starts_with('__py2v__.checked_') && original.api != '__py2v__.checked_text_index' {
		return t.visit_checked_operation(original)
	}
	if original.api == '__py2v__.native_map_pop' && original.func is Attribute
		&& original.args.len == 1 {
		helper := t.runtime_helper('native_map_pop')
		return '${helper}(mut ${t.visit_expr(original.func.value)}, ${t.visit_expr(original.args[0])})'
	}
	if original.api == '__py2v__.required_text' && original.args.len == 1 {
		value := t.visit_expr(original.args[0])
		return "(${value} or { panic('unreachable None after string narrowing') })"
	}
	if original.api == '__py2v__.coroutine_refusal' && original.args.len == 2 {
		message := original.args[0]
		site := original.args[1]
		if message is Constant && message.value is string && site is Constant && site.value is string {
			eprintln('${site.value}: ${message.value}')
			return 'panic(${t.visit_expr(message)})'
		}
	}
	if (original.api == '__py2v__.list_ref_assign_slice' && original.args.len == 6)
		|| (original.api == '__py2v__.list_ref_assign_slice_step' && original.args.len == 7) {
		t.add_using('pyrt')
		typ := get_expr_annotation(original.args[1])
		elem := typ['&pyrt.ListRef['.len..typ.len - 1]
		name := if original.args.len == 7 {
			'list_ref_assign_slice_step'
		} else {
			'list_ref_assign_slice'
		}
		return 'pyrt.${name}[${elem}](${original.args.map(t.visit_expr(it)).join(', ')})'
	}
	if original.api == '__py2v__.list_ref_slice' && original.args.len == 5 {
		t.add_using('pyrt')
		typ := original.v_annotation or { '' }
		elem := typ[2..]
		return 'pyrt.list_ref_slice[${elem}](${original.args.map(t.visit_expr(it)).join(', ')})'
	}
	if original.api == '__py2v__.list_ref' && original.args.len == 1 {
		t.add_using('pyrt')
		typ := original.v_annotation or { '' }
		elem := typ['&pyrt.ListRef['.len..typ.len - 1]
		value := original.args[0]
		if value is List && value.elts.len == 0 {
			return 'pyrt.list_ref[${elem}]([]${elem}{})'
		}
		return 'pyrt.list_ref[${elem}](${t.visit_expr(value)})'
	}

	if original.api == '__py2v__.checked_text_index' && original.args.len == 2 {
		value := t.visit_expr(original.args[0])
		code := t.emit_string_index(value, original.args[1], original.guard > 0 || original.propagate)
		if original.guard > 0 { return t.guarded_call(code, original.guard, false) }
		return if original.propagate { t.propagated_call(code, false) } else { code }
	}
	if original.api == '__py2v__.format_radix' && original.args.len == 2
		&& original.args[1] is Constant {
		specifier := original.args[1] as Constant
		return t.visit_radix_format(original.args[0], specifier.value as string)
	}
	if original.api in ['__py2v__.modular_pow', '__py2v__.native_value_error_modular_pow']
		&& original.args.len == 3 {
		if original.args.any(t.has_u64_bits(it) || t.has_large_integer(it)) {
			return t.refuse_wide('three-argument pow cannot use unbounded or unsigned operands')
		}
		if !original.args.all(t.infer_expr_type(it) in ['int', 'i64', 'bool']) {
			return t.unsupported_site('modular_pow', 'three-argument pow needs native signed integers', '')
		}
		t.add_using('math.bits as ' + t.runtime_helper_name('math_bits'))
		t.runtime_helper('integer_word_product')
		helper := t.runtime_helper('modular_pow')
		args := original.args.map('int(${t.visit_expr(it)})')
		return t.checked_builtin_value_error('${helper}(${args.join(', ')})', original)
	}
	if original.api in ['__py2v__.int_text', '__py2v__.native_value_error_int_text']
		&& original.args.len == 1 {
		return t.parse_native_integer(original, t.visit_expr(original.args[0]), '10')
	}
	if original.api in ['__py2v__.int_base', '__py2v__.native_value_error_int_base']
		&& original.args.len == 2 {
		if t.infer_expr_type(original.args[0]) != 'string'
			|| t.infer_expr_type(original.args[1]) !in ['int', 'i64', 'bool'] {
			return t.unsupported_site('int_base', 'int with a base needs a string and a native signed integer', '')
		}
		value := t.visit_expr(original.args[0])
		base := t.visit_expr(original.args[1])
		return t.parse_native_integer(original, value, 'int(${base})')
	}
	// An adapter can emit a plain vlib call. Only a direct Python method
	// identified by the lexical planner has a generated result method.
	local_method := original.api == '' && original.func is Attribute
	if original.guard > 0 {
		// a call that can fail, in the body of a `try` whose handlers take the error
		code, optional := without_opt(t.visit_expr_at(Call{
			...original
			guard: 0
		}, permit, permit_type))
		guarded := t.guarded_call(code, original.guard, local_method)
		return if optional { '(${guarded}).opt()' } else { guarded }
	}
	if original.propagate {
		// a call that can fail, in straight-line code of a function returning a result
		code, optional := without_opt(t.visit_expr_at(Call{
			...original
			propagate: false
		}, permit, permit_type))
		passed := t.propagated_call(code, local_method)
		if t.active_error_guard > 0 {
			guarded := t.guarded_call(code, t.active_error_guard, local_method)
			return if optional { '(${guarded}).opt()' } else { guarded }
		}
		if t.in_entry && passed != code {
			t.entry_returns_result = true
		}
		return if optional { passed + '.opt()' } else { passed }
	}
	if original.api == '__py2v__.native_list_index' && original.args.len == 2 {
		items := t.infer_expr_type(original.args[0])
		elem := t.infer_expr_type(original.args[1])
		kind := if elem in ['string', 'int', 'i64', 'bool'] && items == '[]${elem}' {
			'typed_list_index'
		} else {
			'dynamic_list_index'
		}
		t.add_using('pyrt')
		helper := t.runtime_helper(kind)
		return '(${helper}(${original.args.map(t.visit_expr(it)).join(', ')}) or { pyrt.fail(err) })'
	}
	if original.api == '__py2v__.enum_lookup' && original.args.len == 1 {
		t.add_using('pyrt')
		class := t.visit_expr(original.func)
		label := t.visit_expr(original.args[0])
		return '(${class}.py2v_enum_lookup(${label}) or { pyrt.fail(err) })'
	}
	if original.api == '__py2v__.max_integer_key' && original.args.len == 1
		&& original.keywords.len == 1 {
		if code := t.visit_integer_key_max(original.args[0], original.keywords[0].value) {
			return code
		}
	}
	if original.api != '' {
		if code := t.runtime_api_call(original) {
			// a result that may hold None becomes V's option once the error is dealt with
			return if runtime_api[original.api].maybe { code + '.opt()' } else { code }
		}
	}
	if constructor := t.visit_init_constructor(original) {
		return constructor
	}
	class_path := expr_class_path(*original.func)
	if name := t.renamed_class(class_path) {
		fields := t.registry.class_fields_by_path[class_path]
		t.known_classes[name] = fields
		t.class_direct_fields[name] = fields
		ctor_args := original.args.map(t.visit_expr(it))
		return t.ctor_struct_literal(name, name, original, ctor_args)
	}
	if completed := t.complete_imported_call(original) {
		return t.visit_expr_at(completed, permit, permit_type)
	}
	mut node := original
	mut bound := false
	if direct := t.bind_module_call(original, true) {
		node = direct
		bound = true
	} else if ordered := t.bind_source_order_call(original) {
		node = ordered
		bound = true
	}
	if !t.emit_pub && original.keywords.len > 0 && original.func is Name {
		callee := (original.func as Name).id
		if callee in t.module_functions && !bound {
			mut effects := false
			for keyword in original.keywords {
				value := keyword.value
				if value !is Constant && value !is Name
					&& !(value is UnaryOp && value.op is USub && value.operand is Constant) {
					effects = true
				}
			}
			if effects || t.module_safe_signatures[callee].raises {
				return t.unsupported_site('keyword_argument_order', 'unproven local keyword binding and evaluation order', '')
			}
		}
	}
	if node.func is Name && node.func.id in t.sum_parameter_kinds {
		kinds := t.sum_parameter_kinds[node.func.id]
		if node.keywords.len > 0 || node.args.any(it is Starred) {
			return t.unsupported_site('unproven_float_sum', 'cannot check the Python float sum argument binding', '')
		}
		for i, arg in node.args {
			if !python_sum_argument_matches(t, arg, kinds[i] or { '' }) {
				return t.unsupported_site('unproven_float_sum', 'argument may contain a Python int in a float sum', '')
			}
		}
	}
	mut fname := t.visit_expr(node.func)

	// Check if this function has mut parameters
	mut_indices := t.mut_param_indices[fname] or { []int{} }

	mut vargs := []string{}
	mut list_arg_slots := []int{}
	declared_params := t.func_param_types[fname] or { []string{} }
	for i, arg in node.args {
		param_type := declared_params[i] or { '' }
		sink := t.wide_call_argument(node, fname, param_type)
		saved_updates := t.integer_update_names
		if t.loop_breaks.len > 0 && node.func is Attribute && node.func.attr == 'append' {
			t.integer_update_names = growth_targets(*node.func.value)
		}
		mut arg_str := if sink == .unapproved {
			t.typed_literal_arg(arg)
		} else {
			t.visit_expr_at(arg, sink, param_type)
		}
		t.integer_update_names = saved_updates
		// A dict literal for a parameter declared with a value type has that type
		if arg is Dict && (arg as Dict).keys.len > 0 && i < declared_params.len
			&& declared_params[i].starts_with('map[') && !declared_params[i].ends_with(']Any') {
			typ := declared_params[i]
			arg_str = typ + t.visit_expr(arg)
		} else if i < declared_params.len {
			arg_str = t.integer_boundary(arg, arg_str, declared_params[i])
		}
		if param_type in ['Any', 'pyrt.Value'] && t.infer_expr_type(arg) == 'Py2vNumber' {
			t.add_using('pyrt')
			arg_str = '${t.runtime_helper('numeric_box')}(${arg_str})'
		}
		if param_type == '[]Py2vNumber' {
			if arg is List {
				arg_str = t.numeric_choice_list(arg)
			} else if t.infer_expr_type(arg) in ['[]f64', '[]int'] {
				arg_str = '${as_receiver(arg_str)}.map(Py2vNumber(it))'
			}
		}
		// Add mut keyword if this parameter index requires it
		if i in mut_indices {
			arg_str = 'mut ${arg_str}'
		}
		// Bound positional arguments keep their source slots; keywords must not gain list widening.
		if i < original.args.len && arg is List && (arg as List).elts.len > 0 {
			list_arg_slots << i
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

	// Keep the local Value alias, which carries this module's Python operators.
	if fname == 'pyrt.map_get' {
		return 'Any(pyrt.map_get(${vargs.join(', ')}))'
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

	// Use vlib only on the domains for which it returns an exact integer.
	if vargs.len == 1 && fname in ['math.isqrt', 'math.factorial'] {
		t.add_using('math')
		if fname == 'math.factorial' {
			if !t.integer_growth_point('factorial', original.args, false) {
				return 'int(math.factoriali(${vargs[0]}))'
			}
			return t.checked_integer('factorial', [vargs[0]], original.loc)
		}
		input := t.native_integer_bounds(original.args[0])
		if input.low >= 0 && input.high < i64(1) << 62 {
			return 'int(math.sqrti(${vargs[0]}))'
		}
		return '${t.runtime_helper('integer_isqrt')}(${vargs[0]})'
	}
	if vargs.len == 2 && fname in ['math.gcd', 'math.lcm'] {
		t.add_using('math')
		return '${fname}[int](${vargs.join(', ')})'
	}
	if vargs.len == 1 && fname in ['math.floor', 'math.ceil', 'math.trunc'] {
		typ := t.infer_expr_type(original.args[0])
		if native_integer_type(typ) {
			return native_integer_input(typ, vargs[0])
		}
		t.add_using('math')
		return 'int(${fname}(${as_f64_argument(typ, vargs[0])}))'
	}

	// `math.log(x, base)`: V's `math.log` takes the value alone.
	if vargs.len == 2 && fname == 'math.log' {
		t.add_using('math')
		return 'math.log_n(${vargs[0]}, ${vargs[1]})'
	}

	// Python's random module → V's rand module
	if fname.starts_with('random.') && t.imported_modules['random'] {
		rand_result, rand_handled := dispatch_random_func(mut t, fname, vargs)
		if rand_handled {
			return rand_result
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
		if member := t.renamed_static_member(attr_node) {
			return '${member}(${vargs.join(', ')})'
		}
		if renamed := t.imported_colliding_function(t.init_python_path(node.func)) {
			return '${renamed}(${vargs.join(', ')})'
		}
		// A `from . import mod` qualifier is Python-only; call the symbol
		// directly rather than rebuilding `mod.method(...)` from the AST.
		collapsed := t.collapse_submodule_attr(attr_node)
		if collapsed != '' {
			// `em.RawResult(...)` after `from . import emulator as em` constructs
			// a class of a sibling file: a struct literal, as for a bare class name.
			// `RawResult(a, b, c)` would be a cast with too many values.
			// The class is looked up in that file only: the same name may be a
			// function there and a class somewhere else.
			sibling := t.submodule_aliases[(attr_node.value as Name).id]
			class_name := attr_node.attr
			sibling_fields := t.registry.class_fields(sibling, class_name)
			sibling_bases := t.registry.class_bases(sibling, class_name)
			if sibling_fields.len > 0 || sibling_bases.len > 0 {
				if class_name !in t.known_classes {
					t.known_classes[class_name] = sibling_fields
					t.class_direct_fields[class_name] = sibling_fields
					t.class_base_names[class_name] = sibling_bases
					t.imported_classes[class_name] = sibling_fields
				}
				mut emitted_ctor := emitted_class_name(class_name)
				if class_name in t.ref_classes {
					emitted_ctor = '&${emitted_ctor}'
				}
				return t.ctor_struct_literal(emitted_ctor, class_name, node, vargs)
			}
			if vargs.len > 0 {
				return '${collapsed}(${vargs.join(', ')})'
			}
			return '${collapsed}()'
		}
		obj := as_receiver(t.visit_expr(attr_node.value))
		method := attr_node.attr
		// Append's operator spelling belongs to the call, never to a bound method value.
		if method == 'append' && vargs.len > 0 {
			if t.infer_expr_type(attr_node.value) == '[]u64'
				&& t.word_bound(node.args[0]) == none {
				return t.refuse_wide('appending an unbounded or negative integer would corrupt a native unsigned list')
			}
			return '${obj} << ${vargs[0]}'
		}

		// An explicit `BuiltinError.__init__(self, ...)` reaches a class V has no
		// counterpart for. Portage does exactly this to mix a builtin exception
		// into its own hierarchy, as in `class E(KeyError, Base)`.
		if method == '__init__' && attr_node.value is Name {
			recv := (attr_node.value as Name).id
			if recv in t.known_classes {
				init_method := t.emitted_init_method(recv)
				// V reaches an embedded base through the receiver, so an explicit
				// `Base.__init__(self, x)` becomes `self.Base.init(x)`: the
				// receiver is implicit in V and must not be forwarded.
				mut base_args := vargs
				if base_args.len > 0 && base_args[0] == 'self' {
					base_args = base_args[1..]
				}
				if base_args.len > 0 {
					return 'self.${emitted_class_name(recv)}.${init_method}(${base_args.join(', ')})'
				}
				return 'self.${emitted_class_name(recv)}.${init_method}()'
			}
			if !t.is_known_module_receiver(recv) {
				t.note_unmapped_call(fname)
				return 'Any(0)'
			}
		}

		// Translate Python super().method(...) to embedded-base calls.
		if attr_node.value is Call {
			super_call := attr_node.value as Call
			if super_call.func is Name && (super_call.func as Name).id == 'super' {
				base_name := t.resolve_super_base()
				if base_name.len > 0 {
					// Base methods are emitted under their V spelling, so a
					// `super().__init__(...)` must target the base's `init`.
					base := t.class_base_names[t.current_class_name][0]
					v_method := if method == '__init__' {
						t.emitted_init_method(base)
					} else {
						python_dunder_method_names[method] or { method }
					}
					// A base method with a `mut self` receiver needs the embedded
					// value itself declared mutable at the call site.
					mut recv := 'self'
					if method == '__init__' || t.mut_receiver_methods['${base_name}_${v_method}'] {
						recv = 'mut self'
					}
					if vargs.len > 0 {
						return '${recv}.${base_name}.${v_method}(${vargs.join(', ')})'
					}
					return '${recv}.${base_name}.${v_method}()'
				}
				mut unresolved_args := []string{}
				for arg in super_call.args { unresolved_args << t.visit_expr(arg) }
				unresolved_args << vargs
				for kw in node.keywords { unresolved_args << t.typed_literal_arg(kw.value) }
				return 'py2v_unsupported_super_${to_symbol_ident(method)}(${unresolved_args.join(', ')})'
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

		// errno / stat / signal / warnings are rewritten at the use site; they do
		// not correspond to a V module import. This runs after the path
		// dispatcher so a `Path` value keeps its own method handling.
		if attr_node.value is Name {
			recv_mod := (attr_node.value as Name).id
			if recv_mod in python_stdlib_inline_modules || recv_mod == 'fcntl' {
				res, ok := dispatch_stdlib_call(mut t, recv_mod, method, vargs)
				if ok {
					return res
				}
			}
		}

		// A method of a builtin type on a name this file declares as `Any` (a parameter of
		// a class the file does not see, an item of a dict of values): the runtime finds
		// the method from what the value is. The frontend does this where it knows the
		// value is of unknown type; this is for the names only the backend typed.
		if method in runtime_dispatched_methods && node.keywords.len == 0
			&& attr_node.value is Name && !node.args.any(it is Starred) {
			recv_name := (attr_node.value as Name).id
			if (t.var_types[recv_name] or { '' }) == 'Any' {
				t.add_using('pyrt')
				mut call_args := [obj, "'${method}'"]
				for arg in vargs {
					call_args << if arg.starts_with('pyrt.') { arg } else { 'pyrt.box(${arg})' }
				}
				return 'pyrt.invoke(${call_args.join(', ')})'
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
				if node.keywords.len == 0 && t.infer_expr_type(attr_node.value) == 'string' {
					return '${t.runtime_helper('split_whitespace')}(${obj})'
				}
				return '${obj}.split(" ")'
			}
			'join' {
				if vargs.len > 0 {
					arg_type := t.infer_expr_type(node.args[0])
					if arg_type == 'Any' {
						// a value of unknown type: the runtime joins what it holds
						t.add_using('pyrt')
						return "pyrt.to_str(pyrt.invoke(pyrt.box(${obj}), 'join', ${vargs[0]}))"
					}
					return '${as_receiver(vargs[0])}.join(${obj})'
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
									mut base_node := Expr(Name{ id: base })
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
												base_node = node.args[parsed]
											} else if parsed < node.args.len {
												base_expr = t.visit_expr(node.args[parsed])
											}
										} else {
											// keyword arg
											for kw in node.keywords {
												if arg := kw.arg {
													if arg == base {
														base_expr = t.visit_expr(kw.value)
														base_node = kw.value
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
												previous := base_node
												base_node = Expr(Attribute{ value: &previous, attr: p })
											} else if opn == 'index' {
												base_type := t.infer_expr_type(base_node)
												is_array := base_type.starts_with('[]') || base_type == 'array'
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
												} else if idxs.len > 0 || (!is_array && operands[idx2].len > 0) {
													mut all_digits := true
													for cch in operands[idx2].bytes() {
														if cch < `0` || cch > `9` {
															all_digits = false
															break
														}
													}
													if all_digits {
														base_expr = '${base_expr}[${idxs}]'
													} else if is_array {
														base_expr = '${base_expr}[${escape_keyword(idxs)}]'
													} else {
														base_expr = '${base_expr}[${v_string_literal(operands[idx2])}]'
													}
												}
												previous := base_node
												base_node = Expr(Subscript{
													value: &previous
													slice: &Expr(Constant{ value: 0 })
												})
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
					// V's array `.count` takes a condition, not a value; a string's
					// `.count` takes the substring, as Python's does.
					recv_type := t.infer_expr_type(attr_node.value)
					recv_ann := get_expr_annotation(attr_node.value)
					if attr_node.value is List || attr_node.value is Tuple
						|| recv_type.starts_with('[]') || recv_ann.starts_with('[]')
						|| recv_ann.starts_with('list') || recv_ann.starts_with('tuple') {
						return '${obj}.count(it == ${vargs[0]})'
					}
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
			'swapcase' {
				if vargs.len == 0 && node.keywords.len == 0
					&& t.infer_expr_type(attr_node.value) == 'string' {
					return '${t.runtime_helper('ascii_swapcase')}(${obj})'
				}
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
			'decode' {
				// bytes to str; the encoding argument is ignored (UTF-8 bytes are kept)
				return '${obj}.bytestr()'
			}
			'zfill' {
				if vargs.len == 1 && node.keywords.len == 0 {
					t.add_using('strings')
					return '${t.runtime_helper('zfill')}(${obj}, ${vargs[0]})'
				}
				return t.unsupported_site('zfill_width', 'zfill needs one positional width', '')
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
				if vargs.len > 0 {
					fill := if vargs.len > 1 { vargs[1] } else { "' '" }
					return '${t.runtime_helper('string_center')}(${obj}, ${vargs[0]}, ${fill})'
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
				// list.remove requires a value. A zero-argument call belongs to
				// the receiver's own protocol (for example a syntax-tree node).
				return '${obj}.remove()'
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
				if t.infer_expr_type(attr_node.value) in t.known_classes {
					return '${obj}.index(${vargs.join(', ')})'
				}
				// Python list.index() / str.index() raise ValueError if not found
				if vargs.len > 0 {
					return "${obj}.index(${vargs[0]}) or { panic('value not found') }"
				}
				return '0'
			}
			'copy' {
				if node.args.len == 0 && node.keywords.len == 0 && attr_node.value is Call {
					receiver := attr_node.value as Call
					if receiver.func is Name {
						name := (receiver.func as Name).id
						if (name == 'range' && obj.starts_with('py2v_range_array'))
							|| (name == 'map' && name !in t.module_functions
								&& !t.is_bound_in_scope(name) && obj.contains('.map(')) {
							return obj
						}
					}
				}
				return '${obj}.clone()'
			}
			'clear' {
				return '${obj}.clear()'
			}
			'reverse' {
				// Python's list.reverse() works in place; V's `reverse()` returns a copy.
				if t.infer_expr_type(attr_node.value).starts_with('[]') {
					return '${obj}.reverse_in_place()'
				}
				return '${obj}.reverse()'
			}
			'sort' {
				// A key on a list of known element type: a stable sort by that key.
				if node.keywords.any(it.arg or { '' } == 'key') {
					mut list_type := t.infer_expr_type(attr_node.value)
					if list_type == '' {
						list_type = get_v_annotation(attr_node.value)
					}
					if list_type.starts_with('[]') && !list_type.contains('Any') {
						elem := list_type[2..]
						if key, reverse := sort_order(mut t, node, elem) {
							if key == '__py2v_non_total_float_key__' {
								return t.unsupported_site('float_sort_key',
									'float keys may contain NaN and require CPython comparison order', '')
							}
							if key != '' {
								return keyed_sort(obj, elem, key, reverse, true)
							}
						}
					}
				}
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
					return obj
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
				v_method := python_dunder_method_names[method] or { escape_keyword(escape_leading_underscore(method)) }
				mut call := if vargs.len > 0 {
					'${obj}.${v_method}(${vargs.join(', ')})'
				} else {
					'${obj}.${v_method}()'
				}
				// list.append becomes the V `<<` operator.
				if method == 'append' && vargs.len > 0 {
					call = '${obj} << ${vargs[0]}'
				}
				// A qualified callee like `sys.exit` or `logging.info` is handled by
				// the builtin table further down; only treat it as a method call
				// when the receiver is a plain local.
				if attr_node.value is Name && !t.is_known_module_receiver((attr_node.value as Name).id)
					&& !(v_method.len > 0 && v_method[0].is_capital()) {
					// Calling a method with a `mut self` receiver mutates the local,
					// so the local must be declared `mut`.
					recv := (attr_node.value as Name).id
					recv_type := t.var_types[recv] or { t.infer_expr_type(attr_node.value) }
					if t.mut_receiver_methods['${recv_type.trim_left('?&')}_${method}'] {
						t.extra_mut_vars[recv] = true
					}
					return call
				}
			}
		}
	}

	// Check if this is a struct constructor call (known class).
	//
	// A bare Name is only a constructor when it names a class: `b.get()` also
	// lands here when the method table above misses, because the receiver may
	// share a class-attr symbol name, and treating that as a constructor would
	// silently drop the method.
	//
	// A qualified name is different. `util.Box(...)` names a class reached
	// through an import and the receiver is a module, not a value, so the lookup
	// uses the bare name while the emitted literal keeps the qualifier: a bare
	// `Box{}` would refer to nothing when the class lives in another V module.
	// A class whose name starts with an underscore is looked up by its Python name:
	// the visited spelling `Hidden_` names nothing.
	if node.func is Name && node.func.id.starts_with('_') && node.func.id in t.known_classes {
		fname = node.func.id
	}
	mut ctor_lookup := fname
	if dot := fname.last_index('.') {
		ctor_lookup = fname[dot + 1..]
	}
	mut is_ctor := ctor_lookup in t.known_classes
	if node.func is Attribute {
		receiver := node.func as Attribute
		if receiver.value is Name && t.is_known_module_receiver((receiver.value as Name).id) {
			if !(ctor_lookup in t.known_classes) {
				// `cache.Blocker(...)` reaches a class this module never
				// transpiled, because it lives in a sibling file of the same V
				// module. The scan registry knows its fields.
				t.seed_class_by_name(ctor_lookup)
			}
			is_ctor = ctor_lookup in t.known_classes
		} else {
			is_ctor = false
		}
	}
	if is_ctor && (ctor_lookup == fname || ctor_lookup == emitted_class_name(ctor_lookup)
		|| (node.args.len == 0 && node.keywords.len == 0)) {
		// Keep the module qualifier: `Box{}` would refer to nothing when the
		// class lives in another V module.
		mut emitted_ctor := emitted_class_name(ctor_lookup)
		if ctor_lookup != fname {
			emitted_ctor = '${fname.all_before_last('.')}.${emitted_ctor}'
		}
		if ctor_lookup in t.ref_classes {
			emitted_ctor = '&${emitted_ctor}'
		}
		return t.ctor_struct_literal(emitted_ctor, fname, node, vargs)
	}
	if node.func is Attribute || (node.func is Name && fname.contains('.')
		&& t.registry.dotted_for_v_module(fname.all_before_last('.')) != '') {
		method := if node.func is Attribute {
			escape_leading_underscore(node.func.attr)
		} else {
			ctor_lookup
		}
		if is_ctor || (method.len > 0 && method[0].is_capital()
			&& (vargs.len != 1 || node.keywords.len > 0)) {
			// V reads module.Type(a, b) as a cast. A constructor must have a
			// resolved lowering; retain every operand in an explicit refusal.
			mut operands := ["'${escape_string(fname)}'"]
			if node.func is Attribute && !(node.func.value is Name
				&& t.is_known_module_receiver(node.func.value.id)) {
				operands << t.visit_expr(node.func.value)
			}
			operands << vargs
			for kw in node.keywords {
				operands << "'${escape_string(kw.arg or { '**' })}'"
				operands << t.visit_expr(kw.value)
			}
			return 'py2v_unsupported_qualified_call(${operands.join(', ')})'
		}
	}

	for kw in node.keywords {
		vargs << t.typed_literal_arg(kw.value)
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

	// A call into a Python module with no V mapping. `ctypes.CDLL(name, true)`
	// is a field access followed by a call as far as V is concerned, so it does
	// not even parse. Report it and yield a zero value so the rest of the module
	// still compiles and the remaining work is visible.
	unmapped_head := unmapped_call_base(fname, t.unmapped_modules)
	if unmapped_head != '' {
		t.note_unmapped_call(fname)
		// The stub yields a value. `Any` is a sum type alias, so it has to be
		// converted to a concrete variant rather than named bare.
		return 'Any(0)'
	}

	// Default call
	mut call_name := escape_fn_name(fname)
	if should_lowercase_call_name(call_name, t.known_classes) {
		call_name = lower_first_ascii(call_name)
	}
	// A bare `[a, b, c]` is a fixed-size array literal, so it cannot be passed
	// where a `[]Any` is expected. `.map(Any(it))` widens it to a slice. This is
	// applied only here, after the builtin and method handlers have run, because
	// those want the literal itself: `len([1, 2])` must not become
	// `len([1, 2].map(Any(it)))`.
	// A parameter declared with an element type takes the literal as it is.
	declared := t.func_param_types[call_name] or { []string{} }
	for slot in list_arg_slots {
		if slot < declared.len && declared[slot].starts_with('[]') && declared[slot] != '[]Any' {
			continue
		}
		if slot < vargs.len {
			vargs[slot] = as_any_slice(vargs[slot])
		}
	}
	// A function of the runtime library: its V name, and, as py2v's functions do not
	// return results yet, a Python exception it raises stops the program.
	if entry := runtime_functions[call_name] {
		module_name := call_name.all_before('.')
		if 'pyrt.${module_name}' in t.usings {
			mut rargs := []string{}
			for i, arg in original.args {
				if i < entry.boxed.len && entry.boxed[i] && t.has_u64_bits(arg) {
					return t.refuse_wide('boxing a native unsigned argument in the runtime loses its value')
				}
				code := t.visit_expr(arg)
				// A parameter that takes any Python value takes the runtime value
				rargs << if i < entry.boxed.len && entry.boxed[i] {
					'pyrt.box(${code})'
				} else {
					code
				}
			}
			// Keyword arguments are the fields of the function's options struct
			for kw in original.keywords {
				name := kw.arg or { continue }
				field := entry.options[name] or { continue }
				value := t.visit_expr(kw.value)
				rargs << if field == 'default_str' {
					'default_str: true'
				} else {
					'${field}: ${value}'
				}
			}
			call := '${module_name}.${entry.v_name}(${rargs.join(', ')})'
			return if entry.raises { '${call} or { panic(err) }' } else { call }
		}
	}
	if vargs.len > 0 {
		return '${call_name}(${vargs.join(', ')})'
	}
	return '${call_name}()'
}

// parse_native_integer shares the decimal and explicit-base parser.
fn (mut t VTranspiler) parse_native_integer(call Call, value string, base string) string {
	t.runtime_helper('integer_overflow')
	parser := t.runtime_helper('int_base')
	helper := if call.api.ends_with('int_base') {
		t.add_using('pyrt')
		t.runtime_helper('int_base_error_text')
	} else {
		parser
	}
	return t.checked_builtin_value_error('${helper}(${value}, ${base}, ${t.integer_site(call.loc)})',
		call)
}

fn (mut t VTranspiler) checked_builtin_value_error(code string, call Call) string {
	if call.api.starts_with('__py2v__.native_value_error_') {
		value := 'IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } })'
		if call.guard > 0 {
			return '(${code} or {\n\tpy2v_err_${call.guard} = ${value}\n\tbreak py2v_try_${call.guard}\n})'
		}
		return '(${code} or { ${t.escape_exception(value)} })'
	}
	if call.guard > 0 {
		t.add_using('pyrt')
		n := call.guard
		return "(${code} or {\n\tpy2v_err_${n} = pyrt.raise('ValueError', err.msg())\n\tbreak py2v_try_${n}\n})"
	}
	if call.propagate {
		t.add_using('pyrt')
		return "(${code} or { return pyrt.raise('ValueError', err.msg()) })"
	}
	return "(${code} or { panic('ValueError: ' + err.msg()) })"
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

// has_class_annotation finds resolved class metadata retained on a field's AST.
fn (t &VTranspiler) has_class_annotation(annotation Expr) bool {
	if expr_class_path(annotation) in t.registry.class_names {
		return true
	}
	return match annotation {
		Name {
			annotation.api.starts_with('__project_type__.') || annotation.api in runtime_class_types || annotation.api in runtime_api
		}
		Attribute {
			annotation.api.starts_with('__project_type__.') || annotation.api in runtime_class_types || annotation.api in runtime_api
		}
		Subscript {
			t.has_class_annotation(*annotation.value) || t.has_class_annotation(*annotation.slice)
		}
		Tuple { annotation.elts.any(t.has_class_annotation(it)) }
		BinOp {
			t.has_class_annotation(*annotation.left) || t.has_class_annotation(*annotation.right)
		}
		else { false }
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
	if !(c >= `A` && c <= `Z`) {
		return false
	}
	// Lowercasing must not land on a V keyword: `Struct(...)` would become
	// `struct(...)`, which V reads as a keyword and cannot parse at all.
	return !is_keyword(lower_first_ascii(name))
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
	if t.native_exceptions.len > 0 && node.attr == '__cause__' {
		value := t.visit_expr(*node.value)
		return '${t.runtime_helper('native_cause_text')}(${value})'
	}
	if name := t.renamed_class(node.class_path) {
		return name
	}
	if member := t.renamed_static_member(node) {
		return member
	}
	if node.bound_append == 'list' {
		return '${t.runtime_helper('append_method')}(mut ${t.visit_expr(node.value)})'
	}
	if node.bound_append != '' {
		return 'py2v_unsupported_bound_append_${node.bound_append}(${t.visit_expr(node.value)})'
	}
	if node.api != '' {
		match node.api {
			'__py2v__.enum_constant' {
				return '${t.visit_expr(node.value)}.${escape_keyword(node.attr.to_lower())}'
			}
			'__py2v__.enum_name' {
				return '${as_receiver(t.visit_expr(node.value))}.py2v_enum_name()'
			}
			'__py2v__.enum_value' {
				return 'int(${t.visit_expr(node.value)})'
			}
			else {}
		}
		if entry := runtime_api[node.api] {
			if entry.kind == 'constant' {
				t.add_using(entry.v_module)
				return '${entry.v_module.all_after_last('.')}.${entry.v_name}'
			}
			if entry.kind == 'property' {
				receiver := t.visit_expr(*node.value)
				return if entry.v_access == 'method' {
					'${receiver}.${entry.v_name}()'
				} else {
					'${receiver}.${entry.v_name}'
				}
			}
		}
	}
	if resolved := t.project_import_name(t.init_python_path(Expr(node))) {
		return resolved
	}
	collapsed := t.collapse_submodule_attr(node)
	if collapsed != '' {
		return collapsed
	}
	if node.value is Name {
		class_name := (node.value as Name).id
		if class_attrs := t.class_attr_symbols[class_name] {
			if sym := class_attrs[node.attr] {
				return sym
			}
		}
	}

	value := as_receiver(t.visit_expr(node.value))
	mut attr := node.attr
	mut field_escaped := false
	// Field names in this table are already escaped. Encoding them again can
	// change reserved-prefix names and point at a nonexistent field.
	if t.current_class_name != '' {
		if escapes := t.class_field_escapes[t.current_class_name] {
			if v_attr := escapes[attr] {
				attr = v_attr
				field_escaped = true
			}
		}
	}
	// Dunder methods are emitted under a different name, so `self.__int__()`
	// must call the method as declared.
	//
	// Everything else has to shed a leading underscore. V reads `x._foo` as the
	// string literal `x.'foo'`, because `_` is a string prefix character, and a
	// leading underscore is not a legal field name either. Python reaches these
	// constantly for private attributes, so the rewrite matches the one the
	// declaration sites apply.
	if !field_escaped {
		attr = python_dunder_method_names[attr] or { escape_leading_underscore(attr) }
	}
	attr_path := '${value}.${attr}'

	// Try attribute dispatch
	result, handled := dispatch_attr(mut t, attr_path)
	if handled {
		return result
	}

	return '${value}.${attr}'
}

fn (mut t VTranspiler) emit_string_index(value string, index Expr, catchable bool) string {
	helper := t.runtime_helper('string_index')
	offset := t.visit_expr(index)
	numeric_offset := if t.infer_expr_type(index) == 'bool' {
		'if ${offset} { i64(1) } else { i64(0) }'
	} else {
		offset
	}
	if catchable {
		t.add_using('pyrt')
		return "(${helper}(${value}, ${numeric_offset}, pyrt.raise('IndexError', 'string index out of range')) or { pyrt.fail(err) })"
	}
	return '(${helper}(${value}, ${numeric_offset}, none) or { panic(err) })'
}

// visit_subscript emits V code for subscript access (Subscript).
pub fn (mut t VTranspiler) visit_subscript(node Subscript) string {
	value := as_receiver(t.visit_expr(node.value))

	if node.is_annotation {
		index := t.visit_expr(node.slice)
		mapped := v_container_type_map[value] or { value }
		if value == 'Tuple' {
			return '(${index})'
		}
		return '${mapped}[${index}]'
	}
	mut receiver_type := t.infer_expr_type(node.value)
	if receiver_type == '' && node.slice is Slice && node.value is Call {
		annotation := get_expr_annotation(node.value)
		if annotation.starts_with('[]') {
			receiver_type = annotation
		}
	}
	// A slice of a proven native sequence retains the sequence type, even
	// when inference does not annotate the intermediate Subscript expression.
	if node.value is Subscript {
		inner := node.value as Subscript
		if inner.slice is Slice && receiver_type != 'string' && !receiver_type.starts_with('[]') {
			original_type := t.infer_expr_type(inner.value)
			if original_type == 'string' || original_type.starts_with('[]') {
				receiver_type = original_type
			}
		}
	}
	if receiver_type == 'string' && node.slice !is Slice && node.slice !is Tuple {
		return t.emit_string_index(value, node.slice, false)
	}
	if node.slice is Slice && (receiver_type.starts_with('[]') || receiver_type == 'string') {
		slice := node.slice as Slice
		if slice.step != none || receiver_type == 'string' {
			step := if stride := slice.step { t.visit_expr(stride) } else { '1' }
			lower := if bound := slice.lower { t.visit_expr(bound) } else { '?int(none)' }
			upper := if bound := slice.upper { t.visit_expr(bound) } else { '?int(none)' }
			input := if receiver_type == 'string' { '${value}.runes()' } else { value }
			result := '${t.runtime_helper('slice_step')}(${input}, ${lower}, ${upper}, ${step})'
			return if receiver_type == 'string' { '${result}.string()' } else { result }
		}
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
		for bound in [slice_node.lower, slice_node.upper, slice_node.step] {
			if index := bound {
				if t.has_u64_bits(index) {
					return t.refuse_wide('slice bound may narrow an unsigned value')
				}
			}
		}
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

	// `grid[:, 1]` indexes several axes at once and one of them is a slice (numpy).
	// V has no such index, and `[.., 1]` does not parse. A call to a function
	// that does not exist keeps the operands and shows the gap at type checking.
	if node.slice is Tuple {
		elts := (node.slice as Tuple).elts
		if elts.any(it is Slice) {
			mut axes := []string{}
			for e in elts {
				if e is Slice {
					lo := if l := e.lower { t.visit_expr(l) } else { 'none' }
					hi := if u := e.upper { t.visit_expr(u) } else { 'none' }
					st := if s := e.step { t.visit_expr(s) } else { 'none' }
					axes << 'py2v_unsupported_slice(${lo}, ${hi}, ${st})'
				} else {
					axes << t.visit_expr(e)
				}
			}
			return 'py2v_unsupported_index_with_slice_axis(${value}, ${axes.join(', ')})'
		}
	}

	mut index := t.visit_expr(node.slice)
	if t.infer_expr_type(node.slice) in ['u64', 'bool'] {
		container := t.infer_expr_type(node.value)
		if container.starts_with('[]') || container in ['string', 'array'] {
			index = 'int(${index})'
		}
	}
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
	if node.elts.len == 0 {
		annotation := node.v_annotation or { '' }
		if annotation.starts_with('list[') {
			typ := map_type(annotation)
			return '${typ}{}'
		}
	}
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
		if get_expr_annotation(Expr(node)).starts_with('&pyrt.ListRef[') {
			t.add_using('pyrt')
			typ := get_expr_annotation(Expr(node))
			elem := typ['&pyrt.ListRef['.len..typ.len - 1]
			if parts.len == 1 { return '(${parts[0]}).clone()' }
			mut result := parts[0]
			for part in parts[1..] { result = 'pyrt.list_concat[${elem}](${result}, ${part})' }
			return result
		}

		mut result := parts[0]
		mut element_type := ''
		mut native := true
		for e in node.elts {
			mut typ := ''
			if e is Starred && e.value is Name {
				array_type := t.infer_expr_type(e.value)
				if array_type.starts_with('[]') {
					typ = array_type[2..]
				}
			} else if e is Constant || e is Name {
				typ = t.infer_expr_type(e)
			}
			if typ !in ['int', 'i64', 'f64', 'string', 'bool', 'u8']
				|| (element_type != '' && typ != element_type) {
				native = false
				break
			}
			element_type = typ
		}
		if native {
			if parts.len == 1 {
				return '${as_receiver(result)}.clone()'
			}
			t.add_using('arrays')
			for part in parts[1..] {
				result = 'arrays.append(${result}, ${part})'
			}
			return result
		}
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
	if node.keys.len == 0 {
		annotation := node.v_annotation or { '' }
		if annotation.starts_with('dict[') {
			typ := map_type(annotation)
			return '${typ}{}'
		}
		// V has no untyped empty map literal; fall back to a string-keyed map,
		// which is what Python code almost always means for `{}`.
		return 'map[string]Any{}'
	}
	return t.dict_literal_body(node)
}

// dict_literal_body renders the `{ k: v, ... }` part of a map literal, without
// the element type.
//
// V requires a separator between map entries and, like every other V literal,
// accepts a trailing comma. Without them a multi-entry dict does not parse and
// the unclosed brace swallows the rest of the function.
fn (mut t VTranspiler) dict_literal_body(node Dict) string {
	mut pairs := []string{}
	for i, key_opt in node.keys {
		if key := key_opt {
			pairs << '\t${t.visit_expr(key)}: ${t.visit_expr(node.values[i])}'
		}
	}
	return '{\n${pairs.join(',\n')},\n}'
}

// typed_literal_arg renders one call argument, giving a collection literal the
// explicit element type V cannot infer in argument position.
pub fn (mut t VTranspiler) typed_literal_arg(arg Expr) string {
	if arg is Dict && (arg as Dict).keys.len > 0 {
		return 'map[${t.dict_key_type(arg)}]Any' + t.visit_expr(arg)
	}
	return t.visit_expr(arg)
}

// dict_key_type guesses the V map key type from the first literal key, so that a
// dict passed straight to a function can carry an explicit element type. V has
// no way to infer one in argument position.
fn (mut t VTranspiler) dict_key_type(node Dict) string {
	for key_opt in node.keys {
		key := key_opt or { continue }
		if key is Constant {
			value := (key as Constant).value
			if value is bool {
				return 'bool'
			}
			if value is int || value is i64 {
				return 'int'
			}
			if value is f64 {
				return 'f64'
			}
			if value is string {
				return 'string'
			}
		}
	}
	return 'string'
}

// visit_set (same as List in V)
pub fn (mut t VTranspiler) visit_set(node Set) string {
	mut elts := []string{}
	mut distinct_constants := true
	for e in node.elts {
		code := t.visit_expr(e)
		if e !is Constant || code in elts {
			distinct_constants = false
		}
		elts << code
	}
	// A set holds each value once: anything but distinct constants is de-duplicated.
	if distinct_constants || elts.len < 2 {
		return '[${elts.join(', ')}]'
	}
	return '${t.runtime_helper('distinct')}([${elts.join(', ')}])'
}

// if_condition emits the test of an `if`. V refuses a condition that starts with a
// parenthesized `if` expression, as `(a if c else b).startswith(x)` becomes.
fn (mut t VTranspiler) if_condition(test Expr) string {
	code := t.visit_expr(test)
	if code.starts_with('if ') || code.starts_with('(if ') {
		return 'true && (${code})'
	}
	// A final capitalized constant looks like a struct type to V. Without
	// parentheses it consumes the following block as a struct initializer.
	mut start := code.len
	for start > 0 && (code[start - 1].is_alnum() || code[start - 1] == `_`) {
		start--
	}
	if start < code.len && code[start].is_capital() {
		prefix := code[..start].trim_space()
		if prefix.ends_with(' is') || prefix.ends_with(' !is') { return code }
		return '(${code})'
	}
	return code
}

// visit_ifexp emits V code for inline if-expressions (IfExp).
pub fn (mut t VTranspiler) visit_ifexp(node IfExp) string {
	test := t.if_condition(node.test)
	// A bare map at the start of a branch is parsed as a statement block.
	body := t.ifexp_branch(node.body)
	orelse := t.ifexp_branch(node.orelse)
	if t.is_numeric_choice(node) {
		if t.emit_pub {
			// Package code already shares the runtime value across module boundaries.
			t.add_using('pyrt')
			return 'if ${test} { pyrt.box(${body}) } else { pyrt.box(${orelse}) }'
		}
		lhs := t.numeric_choice_value(*node.body, body)
		rhs := t.numeric_choice_value(*node.orelse, orelse)
		return 'if ${test} { ${lhs} } else { ${rhs} }'
	}
	return 'if ${test} { ${body} } else { ${orelse} }'
}

fn numeric_choice_result(node FunctionDef) string {
	float_annotation := Expr(Name{ id: 'float' })
	ret := node.returns or { &float_annotation }
	mut list_result := false
	if ret is Subscript {
		collection := *ret.value
		member := *ret.slice
		list_result = collection is Name && collection.id in ['list', 'List']
			&& member is Name && member.id == 'float'
	}
	if !list_result && !(ret is Name && ret.id == 'float') { return '' }
	mut choices := map[string]bool{}
	for stmt in node.body {
		if stmt is Assign && stmt.targets.len == 1 && stmt.targets[0] is Name {
			choices[(stmt.targets[0] as Name).id] = annotated_numeric_choice(*stmt.value)
		}
		if stmt is Return {
			value := stmt.value or { continue }
			if list_result && value is List
				&& value.elts.any(annotated_numeric_choice(it) || (it is Name && choices[it.id])) {
				return '[]Py2vNumber'
			}
			if !list_result && (annotated_numeric_choice(value) || (value is Name && choices[value.id])) {
				return 'Py2vNumber'
			}
		}
	}
	return ''
}

// A literal base case and integer arithmetic on a recursive result prove an
// integer return even when the Python signature permits a float.
fn recursive_int_result(node FunctionDef) bool {
	annotation := node.returns or { return false }
	typ := *annotation
	if typ !is Name || typ.id != 'float' || node.is_class_method {
		return false
	}
	body := node.body.filter(!(it is ExprStmt && it.value is Constant && it.value.value is string))
	if body.len != 1 || body[0] !is Return { return false }
	result := (body[0] as Return).value or { return false }
	if result !is IfExp { return false }
	then := *result.body
	otherwise := *result.orelse
	for i, arm in [then, otherwise] {
		if arm !is BinOp { continue }
		step := arm as BinOp
		if !(step.op is Add || step.op is Sub || step.op is Mult) { continue }
		base := if i == 0 { otherwise } else { then }
		if literal_signed_integer(base) == none { continue }
		for pair in [[*step.left, *step.right], [*step.right, *step.left]] {
			call := pair[0]
			value := pair[1]
			if call is Call && call.func is Name && call.func.id == node.name
				&& (literal_signed_integer(value) != none || (value is Name
					&& node.args.args.any(it.arg == value.id && integer_arg_annotation(it)))) {
				return true
			}
		}
	}
	return false
}

fn integer_arg_annotation(arg Arg) bool {
	annotation := arg.annotation or { return false }
	typ := *annotation
	return typ is Name && typ.id == 'int'
}

fn annotated_numeric_choice(expr Expr) bool {
	if expr !is IfExp { return false }
	a := get_expr_annotation(*expr.body)
	b := get_expr_annotation(*expr.orelse)
	return (a == 'int' && b == 'float') || (a == 'float' && b == 'int')
}

fn (mut t VTranspiler) is_numeric_choice(node IfExp) bool {
	a := t.infer_expr_type(*node.body)
	b := t.infer_expr_type(*node.orelse)
	return (a in ['int', 'i64'] && b in ['float', 'f64'])
		|| (a in ['float', 'f64'] && b in ['int', 'i64'])
}

fn (mut t VTranspiler) numeric_choice_value(expr Expr, code string) string {
	typ := t.infer_expr_type(expr)
	if typ == 'Py2vNumber' { return code }
	t.runtime_helper('float_text')
	t.runtime_helper('numeric_choice')
	cast := if typ in ['f64', 'float', 'f32'] {
		'f64'
	} else if typ in ['int', 'i64'] {
		'int'
	} else {
		''
	}
	return if cast != '' { 'Py2vNumber(${cast}(${code}))' } else { 'Py2vNumber(${code})' }
}

fn (mut t VTranspiler) numeric_choice_list(node List) string {
	if node.elts.len == 0 { return '[]Py2vNumber{}' }
	mut values := []string{cap: node.elts.len}
	for item in node.elts {
		code := t.visit_expr(item)
		values << t.numeric_choice_value(item, code)
	}
	return '[${values.join(', ')}]'
}

fn (mut t VTranspiler) list_repetition(items Expr, count Expr, left string, right string) string {
	if python_numeric_arg_list_kind(t, items) in ['float', 'maybe_float'] {
		if literal := literal_signed_integer(count) {
			return '${as_receiver(left)}.repeat(${if literal < 0 { '0' } else { right }})'
		}
		t.add_using('math')
		return '${as_receiver(left)}.repeat(math.max(0, int(${right})))'
	}
	return '${as_receiver(left)}.repeat(${right})'
}

fn reverse_comparison(op string) string {
	return match op {
		'<' { '>' }
		'<=' { '>=' }
		'>' { '<' }
		'>=' { '<=' }
		else { op }
	}
}

fn (mut t VTranspiler) numeric_float_comparison(left string, right string, op string, float_first bool) string {
	t.add_using('math')
	compare := t.runtime_helper('numeric_compare_float')
	helper := if float_first { t.runtime_helper('numeric_compare_from_float') } else { compare }
	return numeric_comparison_result('${helper}(${left}, ${right})', op)
}

fn (mut t VTranspiler) numeric_int_comparison(number string, integer string, op string) string {
	t.add_using('math')
	t.runtime_helper('numeric_compare_float')
	helper := t.runtime_helper('numeric_compare_int')
	return numeric_comparison_result('${helper}(${number}, int(${integer}))', op)
}

fn numeric_comparison_result(comparison string, op string) string {
	return match op {
		'<' { '${comparison} == -1' }
		'<=' { '${comparison} <= 0' }
		'>' { '${comparison} == 1' }
		'>=' { '(${comparison} in [0, 1])' }
		'!=' { '${comparison} != 0' }
		else { '${comparison} == 0' }
	}
}

// ifexp_value retains the float type of integral literals in a value choice.
// json2 can decode 0.0 as an integer; an int first branch would truncate 2.5.
fn (mut t VTranspiler) ifexp_value(expr Expr) string {
	if expr is Constant && (expr.v_annotation or { '' }) == 'float' {
		code := t.visit_expr(expr)
		return if code.contains('.') || code.contains('e') || code.contains('E') {
			code
		} else {
			'${code}.0'
		}
	}
	if expr is UnaryOp && (expr.op is UAdd || expr.op is USub) && expr.operand is Constant
		&& ((expr.operand as Constant).v_annotation or { '' }) == 'float' {
		return op_to_symbol(get_unary_op_type(expr.op)) + t.ifexp_value(expr.operand)
	}
	return t.visit_expr(expr)
}

// ifexp_branch retains value types and groups map literals in V branches.
fn (mut t VTranspiler) ifexp_branch(expr Expr) string {
	code := t.ifexp_value(expr)
	return if expr is Dict && code.starts_with('{') { '(${code})' } else { code }
}

// list_identity_refusal reports and emits a loud boundary for an unprovable list group.
fn (mut t VTranspiler) list_identity_refusal(reason string) string {
	message := 'py2v: ${reason.replace('\n', ' ')}'
	eprintln(message)
	return '${t.runtime_helper('unsupported_list_identity')}() // ${message}'
}

// visit_integer_key_max keeps the callback's element and integer return types.
fn (mut t VTranspiler) visit_integer_key_max(items Expr, key Expr) ?string {
	if key !is Lambda { return none }
	lambda := key as Lambda
	if lambda.args.args.len != 1 { return none }
	typ := t.infer_expr_type(items)
	if !typ.starts_with('[]') || typ in ['[]', '[]Any'] { return none }
	elem := typ[2..]
	parameter := lambda.args.args[0].arg
	name := escape_local_decl(parameter)
	list := t.visit_expr(items)
	saved_locals := t.local_idents.clone()
	t.local_idents[parameter] = name
	body := t.visit_expr(lambda.body)
	t.local_idents = saved_locals
	t.add_using('pyrt')
	helper := t.runtime_helper('max_integer_key')
	return '(${helper}[${elem}](${list}, fn (${name} ${elem}) int { return ${body} }) or { pyrt.fail(err) })'
}

// visit_lambda emits V code for lambda expressions (Lambda).
pub fn (mut t VTranspiler) visit_lambda(node Lambda) string {
	mut args := []string{}

	// Try to infer types from the body expression
	// If body uses arithmetic, use int; otherwise use generic default
	for arg in node.args.args {
		t.lambda_params[arg.arg]++
	}
	requests_before := t.helper_requests
	body := t.visit_expr(node.body)
	for arg in node.args.args {
		t.lambda_params[arg.arg]--
	}
	stripped_body := strip_outer_parens(body)

	// Check if body contains arithmetic operations
	// A division emitted as a call to the true-division helper is still arithmetic
	body_has_arithmetic := body.contains(' + ') || body.contains(' - ') || body.contains(' * ')
		|| body.contains(' / ') || t.helper_requests > requests_before

	lambda_type := if body_has_arithmetic { 'int' } else { 'string' }

	for arg in node.args.args {
		name := escape_local_decl(arg.arg)
		// Track identifiers escaped due to built-in type name conflicts
		if arg.arg in v_builtin_types {
			t.escaped_identifiers[arg.arg] = true
		}
		// V requires type annotations on each parameter
		// Use annotation if available, otherwise default based on body analysis
		if ann := arg.annotation {
			type_str := t.typename_from_annotation(*ann)
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

	if node.list_identity_error != '' {
		return 'fn (${args.join(', ')}) ${lambda_type} {\n' +
			t.indent_code(t.list_identity_refusal(node.list_identity_error), 1) + '\n}'
	}
	return 'fn (${args.join(', ')}) ${lambda_type} {\n\treturn ${stripped_body}\n}'
}

// visit_list_comp emits V code for list comprehensions (ListComp).
pub fn (mut t VTranspiler) visit_list_comp(node ListComp) string {
	// Should be transformed by VComprehensionRewriter
	// Fallback implementation
	return t.visit_generator_exp_impl(node.elt, node.generators, false)
}

// A package string product can initialize a constant through a closure. Each
// iterable is a native array in the module, so the closure needs no captures.
fn (mut t VTranspiler) module_string_product(node ListComp) ?string {
	if node.generators.len < 2 || node.elt !is BinOp {
		return none
	}
	element := node.elt as BinOp
	if element.op !is Add || element.left !is Name || element.right !is Name {
		return none
	}
	mut targets := map[string]bool{}
	module_names := t.module_idents.values()
	for generator in node.generators {
		if generator.is_async || generator.ifs.len > 0 || generator.iter !is Name
			|| generator.target !is Name {
			return none
		}
		iter_name := (generator.iter as Name).id
		target := (generator.target as Name).id
		if iter_name !in t.module_idents || t.var_types[iter_name] != '[]string'
			|| target in module_names || target in targets || target == 'result'
			|| target == '_' || escape_local_decl(target) != target {
			return none
		}
		targets[target] = true
	}
	if (element.left as Name).id !in targets || (element.right as Name).id !in targets {
		return none
	}
	saved_types := t.var_types.clone()
	defer { t.var_types = saved_types }
	for target, _ in targets {
		t.var_types[target] = 'string'
	}
	return t.visit_generator_exp_impl_walrus(node.elt, node.generators)
}

// visit_set_comp emits V code for set comprehensions (SetComp).
pub fn (mut t VTranspiler) visit_set_comp(node SetComp) string {
	return '${t.runtime_helper('distinct')}(${t.visit_generator_exp_impl(node.elt, node.generators, false)})'
}

// comp_binds_py2v_format reports whether a comprehension target is named like
// the f-string helper.
fn (mut t VTranspiler) comp_binds_py2v_format(generators []Comprehension) bool {
	for gen in generators {
		target := t.visit_expr(gen.target)
		if replace_comp_identifier(target, 'py2v_format', '') != target {
			return true
		}
	}
	return false
}

// visit_dict_comp emits V code for dict comprehensions (DictComp).
pub fn (mut t VTranspiler) visit_dict_comp(node DictComp) string {
	if code := t.visit_map_items_comprehension(node.generators, node.value, *node.key) {
		return code
	}
	// A loop variable with the helper's own name would shadow it.
	binds_helper := t.comp_binds_py2v_format(node.generators)
	if binds_helper {
		t.comp_depth++
	}
	defer {
		if binds_helper {
			t.comp_depth--
		}
	}
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
	return t.visit_generator_exp_impl(node.elt, node.generators, false)
}

fn (mut t VTranspiler) visit_generator_exp_impl(elt Expr, generators []Comprehension, count bool) string {
	if generators.len == 0 {
		return '[]'
	}
	if code := t.visit_map_items_comprehension(generators, elt, none) {
		return code
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
	// A walrus in the element needs a statement too: `.map(...)` takes one
	// expression, and V has no assignment expression.
	if contains_condition_walrus(elt) {
		return t.visit_generator_exp_impl_walrus(elt, generators)
	}
	gen := generators[0]
	if generators.len == 1 && gen.ifs.len > 0 && elt !is Constant
		&& !(elt is Name && gen.target is Name && elt.id == gen.target.id)
		&& !comprehension_uses_runtime(elt) && !gen.ifs.any(comprehension_uses_runtime(it))
		&& (t.comprehension_calls_local_function(elt)
			|| gen.ifs.any(t.comprehension_calls_local_function(it))) {
		if code := t.visit_ordered_comprehension(elt, gen) {
			return code
		}
	}

	// Check if the iter is a range() call - need special handling
	mut result := ''
	iter := generators[0].iter
	target := t.visit_expr(generators[0].target)
	// A target that is not one name is put in place by plain text replacement below,
	// which would also rewrite the arguments of a py2v_format call. A target with the
	// helper's own name would have the call itself renamed.
	plain_replace := !is_comp_identifier(target) || target == 'py2v_format'
	if plain_replace {
		t.comp_depth++
	}
	defer {
		if plain_replace {
			t.comp_depth--
		}
	}

	result = t.visit_expr(iter)
	if iter !is Call && t.is_map_expr(iter) {
		// iterating a dict visits its keys
		result = '${as_receiver(result)}.keys()'
	}

	// Apply filters - need to use 'it' for the element reference
	mut filters := []string{}
	for if_clause in generators[0].ifs {
		mut filter_expr := t.visit_expr(if_clause)
		// Replace target variable with 'it' for filter lambda
		filter_expr = if is_comp_identifier(target) {
			replace_comp_identifier(filter_expr, target, 'it')
		} else {
			filter_expr.replace(target, 'it')
		}
		filters << filter_expr
	}
	if filters.len > 0 {
		predicate := join_conditions(filters, '&&')
		if count {
			return '${as_receiver(result)}.count(${predicate})'
		}
		result = '${as_receiver(result)}.filter(${predicate})'
	}

	// Apply map - need to use 'it' for the element reference
	mut map_expr := t.visit_expr(elt)
	// Replace target variable with 'it' for map lambda
	map_expr = if is_comp_identifier(target) {
		replace_comp_identifier(map_expr, target, 'it')
	} else {
		map_expr.replace(target, 'it')
	}
	// V can allocate C int elements for an inferred native quotient field.
	if elt is BinOp && elt.op is FloorDiv && get_expr_annotation(elt) == 'int' {
		map_expr = 'int(${map_expr})'
	}
	if map_expr == 'it' && (filters.len > 0 || iter is List)
		&& t.infer_expr_type(iter) in ['[]int', '[]i64', '[]f64', '[]string', '[]bool', '[]u8'] {
		return result
	}
	result = '${as_receiver(result)}.map(${map_expr})'

	return result
}

// A local Python function can observe effects between the predicate and projection.
fn (t &VTranspiler) comprehension_calls_local_function(expr Expr) bool {
	if expr is Call && expr.func is Name && expr.func.id in t.module_functions {
		return true
	}
	return condition_walrus_children(expr).any(t.comprehension_calls_local_function(it))
}

// comprehension_uses_runtime keeps adapted values on the existing runtime path.
fn comprehension_uses_runtime(expr Expr) bool {
	return (expr is Call && (expr.api.starts_with('__pyrt__.') || expr.api in runtime_api))
		|| condition_walrus_children(expr).any(comprehension_uses_runtime(it))
}

// comprehension_propagates reports a checked operation inside the generated loop.
fn comprehension_propagates(expr Expr) bool {
	return (expr is Call && expr.propagate)
		|| condition_walrus_children(expr).any(comprehension_propagates(it))
}

// visit_ordered_comprehension emits one loop for a filter and its value expression.
fn (mut t VTranspiler) visit_ordered_comprehension(elt Expr, gen Comprehension) ?string {
	if gen.target !is Name || gen.is_async {
		return none
	}
	target := gen.target.id
	mut typ := t.infer_expr_type(gen.iter)
	if typ == '' {
		typ = get_v_annotation(gen.iter)
	}
	if typ == '' && gen.iter is Call && gen.iter.func is Name && gen.iter.func.id == 'range'
		&& 'range' !in t.module_functions && !t.is_bound_in_scope('range') {
		typ = '[]int'
	}
	if typ !in ['[]int', '[]i64', '[]f64', '[]string', '[]bool', '[]u8'] {
		return none
	}
	source_expr := t.visit_expr(gen.iter)
	mut captures := []string{}
	for predicate in gen.ifs {
		t.map_comprehension_captures(predicate, [target], mut captures)
	}
	t.map_comprehension_captures(elt, [target], mut captures)
	capture := if captures.len > 0 { ' [${captures.join(', ')}]' } else { '' }
	saved_types := t.var_types.clone()
	saved_renames := t.renamed_idents.clone()
	defer {
		t.var_types = saved_types
		t.renamed_idents = saved_renames
	}
	item := t.new_tmp('comp_item')
	values := t.new_tmp('comp_values')
	output := t.new_tmp('comp_output')
	t.renamed_idents[target] = item
	t.var_types[target] = typ[2..]
	elem := if elt is JoinedStr { 'string' } else { t.infer_expr_type(elt) }
	if elem == '' {
		return none
	}
	fallible := comprehension_propagates(elt) || gen.ifs.any(comprehension_propagates(it))
	result := if fallible { '!' } else { '' }
	mut lines := ['(fn${capture} (${values} ${typ}) ${result}[]${elem} {',
		'\tmut ${output} := []${elem}{}', '\tfor ${item} in ${values} {']
	for predicate in gen.ifs {
		lines << '\t\tif !(${t.visit_expr(predicate)}) { continue }'
	}
	lines << ['\t\t${output} << ${t.visit_expr(elt)}', '\t}', '\treturn ${output}',
		'})(${source_expr})${result}']
	return lines.join('\n')
}

// map_comprehension_captures finds enclosing locals read by a filter or element.
fn (t &VTranspiler) map_comprehension_captures(expr Expr, targets []string, mut captures []string) {
	if expr is Name && expr.id !in targets
		&& (t.is_bound_in_scope(expr.id) || (expr.id == 'self' && t.current_class_name != '')) {
		name := t.binding_spelling(expr.id)
		module_constant := t.emit_pub && !t.emitting_function && expr.id in t.module_idents
		if !module_constant && name !in captures {
			captures << name
		}
	}
	for child in condition_walrus_children(expr) {
		t.map_comprehension_captures(child, targets, mut captures)
	}
}

// visit_map_items_comprehension uses the map's native pair iteration and moves
// the first iterable into an explicit parameter so it is evaluated once.
fn (mut t VTranspiler) visit_map_items_comprehension(generators []Comprehension, elt Expr, key ?Expr) ?string {
	if generators.len != 1 || generators[0].is_async || contains_condition_walrus(elt) {
		return none
	}
	gen := generators[0]
	if gen.ifs.any(contains_condition_walrus(it)) {
		return none
	}
	target := *gen.target
	elts := match target {
		Tuple { target.elts }
		List { target.elts }
		else { return none }
	}
	if elts.len != 2 || elts.any(it !is Name) || gen.iter !is Call {
		return none
	}
	targets := for_target_names(target)
	iter := gen.iter as Call
	if iter.args.len != 0 || iter.keywords.len != 0 || iter.func !is Attribute {
		return none
	}
	member := iter.func as Attribute
	typ := t.infer_expr_type(member.value)
	// V variable-length arrays do not retain Python tuple key equality in a map.
	if member.attr != 'items' || !typ.starts_with('map[') || typ.starts_with('map[[]') {
		return none
	}
	mut close := 4
	mut depth := 1
	for close < typ.len && depth > 0 {
		match typ[close] {
			`[` { depth++ }
			`]` { depth-- }
			else {}
		}
		close++
	}
	if depth != 0 || close == typ.len {
		return none
	}
	source_expr := t.visit_expr(member.value)
	mut captures := []string{}
	for predicate in gen.ifs {
		t.map_comprehension_captures(predicate, targets, mut captures)
	}
	if map_key := key {
		t.map_comprehension_captures(map_key, targets, mut captures)
	}
	t.map_comprehension_captures(elt, targets, mut captures)
	capture := if captures.len > 0 { ' [${captures.join(', ')}]' } else { '' }

	saved_types := t.var_types.clone()
	saved_renames := t.renamed_idents.clone()
	defer {
		t.var_types = saved_types
		t.renamed_idents = saved_renames
	}
	source := t.new_tmp('comp_map')
	result := t.new_tmp('comp_result')
	pair_key := t.new_tmp('comp_key')
	pair_value := t.new_tmp('comp_value')
	t.renamed_idents[targets[0]] = pair_key
	t.renamed_idents[targets[1]] = pair_value
	t.var_types[targets[0]] = typ[4..close - 1]
	t.var_types[targets[1]] = typ[close..]

	mut value_type := t.infer_expr_type(elt)
	// A Python tuple is one element of a list, not an array to flatten via V's <<.
	// This is a heterogeneous tuple: keep its identity for indexing and repr.
	tuples := key == none && elt is Tuple && (elt as Tuple).elts.all(it !is Starred)
	if tuples {
		value_type = 'pyrt.Value'
		t.add_using('pyrt')
	}
	if value_type == '' {
		value_type = 'Any'
	}
	mut result_type := '[]${value_type}'
	mut append_lines := []string{}
	if map_key := key {
		key_type := t.infer_expr_type(map_key)
		result_type = 'map[${if key_type == '' { 'string' } else { key_type }}]${value_type}'
		entry_key := t.new_tmp('comp_entry_key')
		entry_value := t.new_tmp('comp_entry_value')
		append_lines << '\t\t${entry_key} := ${t.visit_expr(map_key)}'
		append_lines << '\t\t${entry_value} := ${t.visit_expr(elt)}'
		append_lines << '\t\t${result}[${entry_key}] = ${entry_value}'
	} else if tuples {
		pair := elt as Tuple
		mut boxed := []string{}
		for item in pair.elts {
			boxed << 'pyrt.box(${t.visit_expr(item)})'
		}
		append_lines << '\t\t${result} << pyrt.Value(pyrt.new_tuple([${boxed.join(', ')}]))'
	} else {
		append_lines << '\t\t${result} << ${t.visit_expr(elt)}'
	}
	mut lines := ['(fn${capture} (${source} ${typ}) ${result_type} {',
		'\tmut ${result} := ${result_type}{}', '\tfor ${pair_key}, ${pair_value} in ${source} {']
	for predicate in gen.ifs {
		lines << '\t\tif !(${t.visit_expr(predicate)}) { continue }'
	}
	lines << append_lines
	lines << ['\t}', '\treturn ${result}', '})(${source_expr})']
	return lines.join('\n')
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
	if node.used_as_value {
		value := if val := node.value { t.visit_expr(val) } else { 'none' }
		return 'py2v_unsupported_generator_send(${value})'
	}
	if val := node.value {
		return 'ch <- ${t.visit_expr(val)}'
	}
	return 'ch <- 0'
}

// visit_yield_from emits V code for yield-from expressions (YieldFrom).
pub fn (mut t VTranspiler) visit_yield_from(node YieldFrom) string {
	gen_expr := t.visit_expr(node.value)
	if node.used_as_value {
		return 'py2v_unsupported_yield_from_result(${gen_expr})'
	}
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
	return "'${t.fmtval_segment(node)}'"
}

// fmtval_segment returns the inner interpolation text for one FormattedValue
// node, to be embedded inside a surrounding single-quoted V string.
fn (mut t VTranspiler) fmtval_segment(node FormattedValue) string {
	if node.conversion != -1 && t.is_wide_text_source(node.value) {
		return '\${${t.refuse_wide('f-string conversion of wide-derived text is unproven')}}'
	}
	sink := if node.format_spec == none && t.has_large_integer(node.value)
		&& node.conversion in [-1, int(`s`), int(`r`), int(`a`)] {
		WideSink.decimal_text
	} else {
		WideSink.unapproved
	}
	mut expr := t.visit_expr_at(node.value, sink, '')
	if node.format_spec == none {
		if text := t.native_scalar_text(node.value, expr) {
			expr = text
		}
	}
	return '\${${expr}}'
}

// fstring_spec_args parses a constant f-string format spec with Python's format
// mini-language, [[fill]align][sign][0][width][grouping][.precision][type], and
// returns the arguments py2v_format takes after the value. It returns none for a
// form py2v_format does not cover, which keeps the plain `${expr}` emission.
fn fstring_constant_spec(node FormattedValue) ?string {
	if node.conversion != -1 {
		return none
	}
	raw := node.format_spec or { return none }
	mut spec := ''
	if raw is JoinedStr {
		for part in raw.values {
			if part is Constant && part.value is string {
				spec += part.value as string
			} else {
				return none
			}
		}
	}
	return spec
}

fn fstring_spec_args(spec string, radix bool) ?string {
	r := spec.runes()
	if r.len == 0 {
		return none
	}
	mut i := 0
	mut fill := ''
	mut align := ''
	if r.len >= 2 && r[1] in [`<`, `>`, `^`, `=`] {
		if r[0] in [`'`, `"`, `\\`, `$`] {
			return none
		}
		fill = r[0].str()
		align = r[1].str()
		i = 2
	} else if r[0] in [`<`, `>`, `^`, `=`] {
		align = r[0].str()
		i = 1
	}
	mut sign := ''
	if i < r.len && r[i] in [`+`, `-`, ` `] {
		sign = r[i].str()
		i++
	}
	alternate := radix && i < r.len && r[i] == `#`
	if alternate { i++ }
	zero := i < r.len && r[i] == `0`
	if zero {
		i++
	}
	mut width := 0
	for i < r.len && r[i] >= `0` && r[i] <= `9` {
		width = width * 10 + int(r[i] - `0`)
		i++
	}
	mut group := ''
	if i < r.len && r[i] in [`,`, `_`] {
		group = r[i].str()
		i++
	}
	mut prec := -1
	if i < r.len && r[i] == `.` {
		prec = 0
		i++
		for i < r.len && r[i] >= `0` && r[i] <= `9` {
			prec = prec * 10 + int(r[i] - `0`)
			i++
		}
	}
	kind := if i < r.len { r[i].str() } else { '' }
	if i + kind.runes().len != r.len {
		return none
	}
	if radix {
		if kind !in ['b', 'o', 'x', 'X'] || group == ',' || prec >= 0 {
			return none
		}
	} else if kind !in ['', 'd', 's', 'e', 'E', 'f', 'F', 'g', 'G', '%']
		|| (group != '' && (zero || align == '=')) {
		return none
	}
	typ := if alternate { '#${kind}' } else { kind }
	return "'${fill}', '${align}', '${sign}', ${zero}, ${width}, '${group}', ${prec}, '${typ}'"
}

fn (mut t VTranspiler) visit_radix_format(value Expr, spec string) string {
	args := fstring_spec_args(spec, true) or {
		return t.unsupported_site('radix_format', 'unsupported integer format specifier', '')
	}
	typ := t.infer_expr_type(value)
	if !is_v_int_type(typ) && typ != 'bool' {
		return t.unsupported_site('radix_format', 'radix formatting requires a native integer', '')
	}
	t.add_using('strconv')
	helper := t.runtime_helper('format_radix')
	code := t.visit_expr_at(value, .decimal_text, '')
	number := if typ == 'bool' { 'int(${code})' } else { code }
	return '${helper}(${number}, ${args})'
}

// py2v_format_helper is emitted once per V module whose f-strings call py2v_format.
const py2v_format_helper = r"// py2v_format formats x as Python's format(x, spec) does, from the spec fields
// py2v parsed: fill, align ('' for the default), sign, the 0 flag, width,
// grouping separator, precision (-1 when absent) and type.
fn py2v_format[T](x T, fill string, align string, sign string, zero bool, width int, group string, prec int, typ string) string {
	mut body := ''
	mut numeric := true
	$if T is rune {
		numeric = false
		body = if prec == 0 { '' } else { x.str() }
	} $else $if T is $int {
		if typ in ['e', 'E', 'f', 'F', 'g', 'G', '%'] {
			body = py2v_format_float(f64(x), sign, prec, typ)
		} else {
			mut neg := false
			mut mag := u64(0)
			$if T is u64 {
				mag = x
			} $else {
				v := i64(x)
				neg = v < 0
				mag = if neg { u64(-(v + 1)) + 1 } else { u64(v) }
			}
			body = if neg { '-' } else if sign == '-' { '' } else { sign }
			body += mag.str()
		}
	} $else $if T is $float {
		if typ !in ['e', 'E', 'f', 'F', 'g', 'G', '%'] {
			return '${x}'
		}
		body = py2v_format_float(f64(x), sign, prec, typ)
	} $else $if T is string {
		numeric = false
		body = if prec >= 0 { x.runes()#[..prec].string() } else { x }
	} $else {
		return '${x}'
	}
	if group != '' {
		i := if body[0] in [`+`, `-`, ` `] { 1 } else { 0 }
		mut j := i
		for j < body.len && body[j].is_digit() {
			j++
		}
		mut digits := body[i..j]
		mut grouped := ''
		for digits.len > 3 {
			grouped = group + digits[digits.len - 3..] + grouped
			digits = digits[..digits.len - 3]
		}
		body = body[..i] + digits + grouped + body[j..]
	}
	pad := width - body.runes().len
	a := if align != '' { align } else if !numeric { '<' } else if zero { '=' } else { '>' }
	f := if fill != '' { fill } else if zero { '0' } else { ' ' }
	return match a {
		'<' { body + f.repeat(pad) }
		'^' { f.repeat(pad / 2) + body + f.repeat(pad - pad / 2) }
		'=' {
			s := if body[0] in [`+`, `-`, ` `] { body[..1] } else { '' }
			s + f.repeat(pad) + body[s.len..]
		}
		else { f.repeat(pad) + body }
	}
}

// Round the exact binary64 decimal expansion to the requested number of places.
fn py2v_format_float(x f64, sign string, prec int, typ string) string {
	value := if typ == '%' { x * 100.0 } else { x }
	bits := math.f64_bits(value)
	biased := int((bits >> 52) & 0x7ff)
	fraction := bits & 0x000f_ffff_ffff_ffff
	negative := bits >> 63 != 0 && !(biased == 0x7ff && fraction != 0)
	prefix := if negative { '-' } else if sign != '-' { sign } else { '' }
	suffix := if typ == '%' { '%' } else { '' }
	upper := typ in ['E', 'F', 'G']
	if biased == 0x7ff {
		word := if fraction == 0 { 'inf' } else { 'nan' }
		return prefix + (if upper { word.to_upper() } else { word }) + suffix
	}
	mut digits := '0'
	mut scale := 0
	if value != 0.0 {
		mantissa := py2v_big.integer_from_u64(if biased == 0 { fraction } else { fraction | (u64(1) << 52) })
		unit := if biased == 0 { -1074 } else { biased - 1075 }
		if unit >= 0 {
			digits = mantissa.left_shift(u32(unit)).str()
		} else {
			scale = -unit
			digits = (mantissa * py2v_big.integer_from_int(5).pow(u32(scale))).str()
		}
	}
	p := if prec >= 0 { prec } else { 6 }
	if typ in ['f', 'F', '%'] {
		fixed := py2v_format_round(digits, digits.len - scale + p)
		return prefix + py2v_format_point(fixed, fixed.len - p) + suffix
	}
	general := typ in ['g', 'G']
	significant := if general && p == 0 { 1 } else if general { p } else { p + 1 }
	mut exponent := digits.len - scale - 1
	mut rounded := py2v_format_round(digits, significant)
	if rounded.len > significant {
		exponent++
		rounded = rounded[..significant]
	}
	if general && exponent >= -4 && exponent < significant {
		return prefix + py2v_format_trim(py2v_format_point(rounded, exponent + 1))
	}
	mantissa := py2v_format_point(rounded, 1)
	marker := if upper { 'E' } else { 'e' }
	exp_sign := if exponent < 0 { '-' } else { '+' }
	exp_digits := (if exponent < 0 { -exponent } else { exponent }).str()
	return prefix + (if general { py2v_format_trim(mantissa) } else { mantissa }) +
		marker + exp_sign + '0'.repeat(2 - exp_digits.len) + exp_digits
}

fn py2v_format_round(digits string, keep int) string {
	if keep >= digits.len {
		return digits + '0'.repeat(keep - digits.len)
	}
	if keep < 0 {
		return '0'
	}
	kept := if keep == 0 { '0' } else { digits[..keep] }
	next := digits[keep]
	odd := (kept[kept.len - 1] - 48) % 2 != 0
	if next > 53 || (next == 53 && (odd || digits[keep + 1..].trim_left('0') != '')) {
		integer := py2v_big.integer_from_string(kept) or { panic(err) }
		return (integer + py2v_big.integer_from_int(1)).str()
	}
	return kept
}

fn py2v_format_point(digits string, point int) string {
	if point <= 0 {
		return '0.' + '0'.repeat(-point) + digits
	}
	if point >= digits.len {
		return digits + '0'.repeat(point - digits.len)
	}
	return digits[..point] + '.' + digits[point..]
}

fn py2v_format_trim(value string) string {
	return if value.contains('.') { value.trim_right('0').trim_right('.') } else { value }
}"

// visit_joined_str emits V code for an f-string (JoinedStr) as a single
// V interpolated string literal `'...${expr}...'`.
pub fn (mut t VTranspiler) visit_joined_str(node JoinedStr) string {
	if node.values.len == 0 {
		return "''"
	}
	mut inner := ''
	// The delimiter is chosen from all the literal text at once: double quotes
	// only when the text holds a `'` and no `"` anywhere. Choosing it piece by
	// piece ended the literal at the first `"` of a later piece.
	mut has_single := false
	mut has_double := false
	for val in node.values {
		if val is Constant {
			if val.value is string {
				s := val.value as string
				has_single = has_single || s.contains("'")
				has_double = has_double || s.contains('"')
			}
		}
	}
	use_double := has_single && !has_double
	for val in node.values {
		match val {
			Constant {
				if val.value is string {
					s := val.value as string
					// Escape special chars; protect `${` from being treated as
					// interpolation.
					mut piece := escape_interp_string(s)
					if use_double {
						// In a double-quoted V string `\'` is an invalid escape.
						piece = piece.replace("\\'", "'")
					}
					inner += piece
				}
			}
			FormattedValue {
				if spec := fstring_constant_spec(val) {
					if spec.len > 0 && spec[spec.len - 1] in [`b`, `o`, `x`, `X`] {
						inner += '\${${t.visit_radix_format(val.value, spec)}}'
						continue
					}
					if t.comp_depth != 0 {
						inner += t.fmtval_segment(val)
						continue
					}
					if args := fstring_spec_args(spec, false) {
						t.uses_py2v_format = true
						t.add_using('math')
						t.add_using('math.big as py2v_big')
						inner += '\${py2v_format(${t.visit_expr(val.value)}, ${args})}'
						continue
					}
				}
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
// V has no assignment expression. Update a previously bound name through a
// helper that yields the assigned value, preserving surrounding evaluation order.
pub fn (mut t VTranspiler) visit_named_expr(node NamedExpr) string {
	if t.has_wide_destination(node.target) {
		return t.refuse_wide('unsigned storage requires a single scalar assignment')
	}
	target := t.visit_expr(node.target)
	value := t.visit_expr(node.value)
	if node.target is Name && t.is_bound_in_scope(node.target.id) {
		return '${t.runtime_helper('assign_expr')}(&(${target}), ${value})'
	}
	return "py2v_unsupported_assignment_expression('${escape_string(target)}', ${value})"
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
	// A loop variable or a walrus target here becomes a V local, which would shadow
	// the helper if it had its name, so f-string specs are not kept in this lowering.
	t.comp_depth++
	defer { t.comp_depth-- }
	// Determine element type for result array
	elem_type := t.infer_expr_type(elt)
	arr_type := if elem_type.len > 0 && elem_type != 'Any' {
		'[]${elem_type}'
	} else {
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
	for line in t.comprehension_element_lines(elt) {
		lines << '${elem_indent}${line}'
	}

	// Close all opened braces
	for i := close_braces; i > 0; i-- {
		lines << '${tab.repeat(i)}}'
	}

	lines << '${tab}return result'
	lines << '})()'
	return lines.join('\n')
}

// comprehension_element_lines appends one element inside the loop that
// visit_generator_exp_impl_walrus writes. A walrus in the element is assigned
// on its own line first, which is sound only for the one shape handled here: a
// single walrus that Python evaluates before anything else in the element
// (`int(last) if (last := name.split('-')[-1]).isdigit() else 0`). Any other
// placement is reported by a call to a function that does not exist.
fn (mut t VTranspiler) comprehension_element_lines(elt Expr) []string {
	if !contains_condition_walrus(elt) {
		return ['result << ${t.visit_expr(elt)}']
	}
	if ne := first_evaluated_walrus(elt) {
		target_expr := *ne.target
		if target_expr is Name && !contains_condition_walrus(*ne.value)
			&& count_condition_walruses(elt) == 1 {
			target := t.visit_expr(target_expr)
			value := t.visit_expr(*ne.value)
			element := t.visit_expr(elt).replace(t.visit_named_expr(ne), target)
			if !element.contains(':=') {
				return ['${target} := ${value}', 'result << ${element}']
			}
		}
	}
	return ['result << py2v_unsupported_walrus_in_comprehension_element()']
}

// first_evaluated_walrus returns the walrus that is the first thing Python
// evaluates in `expr`, if there is one: it follows only the operand each
// expression evaluates first.
fn first_evaluated_walrus(expr Expr) ?NamedExpr {
	match expr {
		NamedExpr { return expr }
		IfExp { return first_evaluated_walrus(*expr.test) }
		Call { return first_evaluated_walrus(*expr.func) }
		Attribute { return first_evaluated_walrus(*expr.value) }
		Subscript { return first_evaluated_walrus(*expr.value) }
		Compare { return first_evaluated_walrus(*expr.left) }
		BinOp { return first_evaluated_walrus(*expr.left) }
		UnaryOp { return first_evaluated_walrus(*expr.operand) }
		BoolOp {
			if expr.values.len > 0 {
				return first_evaluated_walrus(expr.values[0])
			}
			return none
		}
		else { return none }
	}
}

// count_condition_walruses counts the walruses anywhere in `expr`.
fn count_condition_walruses(expr Expr) int {
	mut count := if expr is NamedExpr { 1 } else { 0 }
	for child in condition_walrus_children(expr) {
		count += count_condition_walruses(child)
	}
	return count
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
			mut op_assign := ':='
			if ne.target is Name && t.condition_walrus_vars[(ne.target as Name).id] {
				// Another selected condition reserved this same target. Keep
				// the legacy comparison, but assign to its enclosing binding.
				op_assign = '='
				typ := t.condition_walrus_type(*ne.value)
				if typ != '' {
					name := (ne.target as Name).id
					t.condition_walrus_types[name] = typ
					t.var_types[name] = typ
				}
			}
			assign_line := '${target} ${op_assign} ${value}'
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

// prescan_abc_names walks every statement of the module, at any depth, before
// anything is rendered, and records each class named Sequence, Iterable or Mapping:
// wherever it is defined, such a name is then never mapped.
fn (mut t VTranspiler) prescan_abc_names(stmts []Stmt) {
	for stmt in stmts {
		match stmt {
			ClassDef {
				if stmt.name in ['Iterable', 'Mapping', 'Sequence'] {
					t.module_classes[stmt.name] = true
				}
				t.prescan_abc_names(stmt.body)
			}
			FunctionDef, AsyncFunctionDef, With, AsyncWith {
				t.prescan_abc_names(stmt.body)
			}
			If, For, AsyncFor, While {
				t.prescan_abc_names(stmt.body)
				t.prescan_abc_names(stmt.orelse)
			}
			Try {
				t.prescan_abc_names(stmt.body)
				for handler in stmt.handlers {
					t.prescan_abc_names(handler.body)
				}
				t.prescan_abc_names(stmt.orelse)
				t.prescan_abc_names(stmt.finalbody)
			}
			Match {
				for case in stmt.cases {
					t.prescan_abc_names(case.body)
				}
			}
			else {}
		}
	}
}

// abc_named_classes lists which of Sequence, Iterable and Mapping name a class of
// this module: an annotation of such a class is left as the class, not mapped.
fn (t &VTranspiler) abc_named_classes() []string {
	return ['Iterable', 'Mapping', 'Sequence'].filter(it in t.module_classes)
}

// map_type is map_type() that leaves a class of this module named Sequence,
// Iterable or Mapping as the class.
fn (t &VTranspiler) map_type(typename string) string {
	return t.ref_type(map_type_except(typename, t.abc_named_classes()))
}

// prescan_ref_classes records the classes that declare a field of their own type,
// plain or optional.
fn (mut t VTranspiler) prescan_ref_classes(stmts []Stmt) {
	for stmt in stmts {
		if stmt is ClassDef {
			for _, typename in stmt.declarations {
				if typename == '' {
					continue
				}
				mapped := map_type_except(typename, t.abc_named_classes())
				if mapped.trim_left('?&') == stmt.name {
					t.ref_classes[stmt.name] = true
					break
				}
			}
			t.prescan_ref_classes(stmt.body)
		}
	}
}

// is_ref_class_type tells whether a V type is a reference class, a reference to
// one or an optional of one.
fn (t &VTranspiler) is_ref_class_type(typ string) bool {
	return typ.trim_left('?&') in t.ref_classes
}

// ref_type writes each reference class named in a V type as a reference:
// `?Node` becomes `?&Node` and `[]Node` becomes `[]&Node`.
fn (t &VTranspiler) ref_type(typ string) string {
	if t.ref_classes.len == 0 || typ == '' {
		return typ
	}
	mut out := []u8{cap: typ.len + 4}
	mut i := 0
	for i < typ.len {
		c := typ[i]
		if c.is_letter() || c == `_` {
			mut j := i
			for j < typ.len && (typ[j].is_letter() || typ[j].is_digit() || typ[j] == `_`) {
				j++
			}
			word := typ[i..j]
			if word in t.ref_classes && (i == 0 || typ[i - 1] !in [`&`, `.`]) {
				out << `&`
			}
			out << word.bytes()
			i = j
			continue
		}
		out << c
		i++
	}
	return out.bytestr()
}

// typename_from_annotation extracts a typename string from an annotation expression.
// Accept an optional annotation (`?Expr`) so callers that hold optional
// annotation fields (e.g., `Arg.annotation ?Expr`) can pass them directly
// without causing Option/Expr mismatches during codegen.
pub fn (mut t VTranspiler) typename_from_annotation(ann ?Expr) string {
	return t.ref_type(t.annotation_typename(ann))
}

// annotation_typename is typename_from_annotation before reference classes are
// written as references.
fn (mut t VTranspiler) annotation_typename(ann ?Expr) string {
	// If no annotation was provided, return empty string to indicate
	// "no annotation" (callers often treat empty as missing and use
	// fallbacks). This avoids assigning a concrete default type where
	// the caller may prefer to apply other inference heuristics.
	a := ann or { return '' }
	if name := t.renamed_class(expr_class_path(a)) {
		return name
	}

	// A class of the runtime library named in an annotation
	api := match a {
		Name { a.api }
		Attribute { a.api }
		else { '' }
	}
	if api.starts_with('__project_type__.') {
		target := api.trim_string_left('__project_type__.')
		owner := t.registry.lookup(target.all_before_last('.'))
		if owner.dotted == '' {
			return 'Any'
		}
		name := emitted_class_name(target.all_after_last('.'))
		if owner.v_module == t.module_name { return name }
		t.add_using(owner.v_module)
		return '${owner.v_module}.${name}'
	}
	if v_type := runtime_class_types[api] {
		t.add_using(v_type.all_before('|'))
		return v_type.all_after('|')
	}
	// The manifest's own statement of a class's V type
	if made := runtime_api[api] {
		if made.v_type != '' && made.v_import != '' {
			t.add_using(made.v_import)
			return if made.v_ref { '&${made.v_type}' } else { made.v_type }
		}
	}

	match a {
		Name {
			name := a.id
			if name.contains('pyrt.ListRef[') { t.add_using('pyrt') }
			// A parameter that holds a class (`unit: type = int`) has no V type.
			if name == 'type' {
				return 'Any'
			}
			if name in v_type_map {
				return v_type_map[name]
			}
			// Bare, `Callable` has no V spelling and `MutableSequence` is a bare `list`.
			if name in ['Callable', 'MutableSequence'] {
				return map_type(name)
			}
			return name
		}
		Subscript {
			// The name being parameterized is read as written: `list` in `list[int]` is
			// not the bare `list` annotation.
			subscripted := *a.value
			value := if subscripted is Name
				&& subscripted.id in ['list', 'List', 'set', 'Set', 'Dict', 'Callable',
					'MutableSequence', 'type', 'Type'] {
				subscripted.id
			} else {
				t.annotation_typename(subscripted)
			}
			if value in ['ClassVar', 'Final'] {
				return t.annotation_typename(*a.slice)
			}
			if value in ['type', 'Type'] {
				return 'Any'
			}

			// Union[A, B, ...] → V named sum type comment; inline use emits first type
			// with a note. When used as a parameter annotation we emit a comment.
			if value == 'Union' {
				// Collect all union members from the slice
				mut members := []string{}
				if a.slice is Tuple {
					for e in (a.slice as Tuple).elts {
						members << t.annotation_typename(e)
					}
				} else {
					members << t.annotation_typename(*a.slice)
				}
				// Check for Optional pattern: Union[X, None]
				if members.len == 2 && members[1] == 'none' {
					return '?${t.map_type(members[0])}'
				}
				if members.len == 2 && members[0] == 'none' {
					return '?${t.map_type(members[1])}'
				}
				// General multi-type union — V requires a named sum type.
				// Return Any (compiles cleanly); store a hint comment for the caller.
				union_str := members.join(' | ')
				t.pending_type_notes << '// NOTE: Union[${members.join(', ')}] — define: type X = ${union_str}'
				return 'Any'
			}

			// Optional[X] → ?X
			if value == 'Optional' {
				inner := t.annotation_typename(*a.slice)
				return '?${t.map_type(inner)}'
			}

			// Callable[[A, B], R] → fn(A, B) R
			if value == 'Callable' {
				if a.slice is Tuple {
					elts := (a.slice as Tuple).elts
					if elts.len == 2 {
						mut param_types := []string{}
						if elts[0] is List {
							for pe in (elts[0] as List).elts {
								param_types << t.annotation_typename(pe)
							}
						} else {
							param_types << t.annotation_typename(elts[0])
						}
						ret_type := t.annotation_typename(elts[1])
						if ret_type == '' || ret_type == 'None' || ret_type == 'none' {
							return 'fn (${param_types.join(', ')})'
						}
						return 'fn (${param_types.join(', ')}) ${ret_type}'
					}
				}
				return 'fn (Any) Any'
			}

			raw_index := t.annotation_typename(*a.slice)
			index := if raw_index == '' { 'Any' } else { raw_index }

			// A class of this module named Sequence or Iterable stays that class.
			mapped := if value in t.abc_named_classes() {
				value
			} else {
				v_container_type_map[value] or { value }
			}
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
						elem_types << t.annotation_typename(e)
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
						return '[]${t.map_type(elem_types[0])}'
					}
				}
				// Uniform types → fixed-size array [N]T
				first_et := elem_types[0]
				all_same := elem_types.all(it == first_et)
				if all_same {
					mapped_et := t.map_type(first_et)
					return '[${elem_types.len}]${mapped_et}'
				}
				// Mixed types — no direct V equivalent; emit []Any with a hint.
				joined := elem_types.join(', ')
				t.pending_type_notes << '// NOTE: Tuple[${joined}] — define a struct with named fields'
				return '[]Any'
			}
			if base_name == 'Literal' {
				// Literal[v1, v2, ...] — extract the common value type and emit it.
				mut lit_types := []string{}
				if a.slice is Tuple {
					for e in (a.slice as Tuple).elts {
						lit_types << t.annotation_typename(e)
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
				base_type := if unique.len == 1 { t.map_type(unique[0]) } else { 'Any' }
				t.pending_type_notes << '// NOTE: Literal[${index}] — allowed values are ${index}'
				return base_type
			}
			if t.init_import_aliases[value] == 'collections.defaultdict' {
				if a.slice is Tuple && a.slice.elts.len == 2 {
					key := t.annotation_typename(a.slice.elts[0])
					element := t.annotation_typename(a.slice.elts[1])
					if element != '' {
						// Match the constructor for unknown keys; preserve concrete key types.
						map_key := if key == '' || key == 'Any' { 'string' } else { key }
						return 'map[${map_key}]${element}'
					}
				}
				return 'map[string]Any'
			}
			if base_name == 'Dict' || base_name == 'dict'
				|| (base_name == 'Mapping' && 'Mapping' !in t.abc_named_classes()) {
				// Dict[K, V] — V spells this map[K]V, with no comma. The slice is
				// a Tuple of two elements, so recurse over each separately.
				if a.slice is Tuple {
					kvs := (a.slice as Tuple).elts
					if kvs.len == 2 {
						mut k := t.annotation_typename(kvs[0])
						mut v := t.annotation_typename(kvs[1])
						if k == '' {
							k = 'Any'
						}
						if v == '' {
							v = 'Any'
						}
						return 'map[${k}]${v}'
					}
				}
				return 'map[${index}]Any'
			}
			// A None type argument denotes the singleton type. In a generic
			// specialization it must occupy a slot, even though a bare None
			// return annotation denotes no result.
			if mapped == value && value.len > 0 && value[0].is_capital() && a.slice is Tuple
				&& a.slice.elts.any(it is Constant && it.value is NoneValue) {
				mut type_args := []string{cap: a.slice.elts.len}
				for argument in a.slice.elts {
					if argument is Constant && argument.value is NoneValue {
						t.add_using('pyrt')
						type_args << 'pyrt.NoneType'
					} else {
						type_args << t.annotation_typename(argument)
					}
				}
				return '${mapped}[${type_args.join(', ')}]'
			}
			// User-defined generic (e.g. Stack[T]) — emit Name[T] style only when
			// the base type is a user class name (PascalCase/UpperCase start) and the
			// index is a real type name, not a numeric literal mapped to Any.
			if mapped == value && value.len > 0 && value[0].is_capital() && index.len > 0
				&& index != 'Any' && index[0].is_letter() {
				return '${mapped}[${index}]'
			}
			// A type argument that starts with a sigil (`Token[str | None]` gives
			// `?string`) cannot be glued to the name: `Token?string` is not a type.
			if mapped == value && value.len > 0 && (value[0].is_letter() || value[0] == `_`)
				&& index.len > 0 && index[0] in [`?`, `[`, `&`] {
				return '${mapped}[${index}]'
			}
			return '${mapped}${index}'
		}
		Tuple {
			mut types := []string{}
			for e in a.elts {
				types << t.annotation_typename(e)
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
			// A bare `typing.Sequence` or `typing.Iterable` has no element type, so it
			// keeps its name; the Subscript branch maps `typing.Sequence[T]`.
			if attr in v_container_type_map && attr !in ['Iterable', 'Sequence'] {
				return v_container_type_map[attr]
			}
			return attr
		}
		BinOp {
			// PEP 604: X | None -> ?X
			if a.op is BitOr {
				left := t.annotation_typename(*a.left)
				right := t.annotation_typename(*a.right)
				// X | None -> ?X
				if a.right is Constant {
					r := a.right as Constant
					if r.value is NoneValue {
						return '?${t.map_type(left)}'
					}
				}
				// None | X -> ?X
				if a.left is Constant {
					l := a.left as Constant
					if l.value is NoneValue {
						return '?${t.map_type(right)}'
					}
				}
				// General union: V needs a named sum type; emit Any with a hint.
				l := t.map_type(left)
				r := t.map_type(right)
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
				// A quoted union (`'Ctx | None'`) or a quoted subscript
				// (`'tuple[str|None, int]'`) is mapped from its text. Text the
				// mapping leaves as Python is not a V type and becomes Any.
				if s.contains('|') || s.contains('[') {
					spaced := s.replace('|', ' | ').split(' ').filter(it != '').join(' ')
					mapped := map_type(spaced)
					if is_plain_v_type(mapped) {
						return mapped
					}
					t.pending_type_notes << '// NOTE: annotation "${s}" has no V type here'
					return 'Any'
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

// is_plain_v_type reports whether `typ` is spelled only with what a V type made
// of names, arrays, maps, options and references uses, with its brackets paired.
fn is_plain_v_type(typ string) bool {
	if typ == '' {
		return false
	}
	mut depth := 0
	for c in typ {
		if c == `[` {
			depth++
		} else if c == `]` {
			depth--
			if depth < 0 {
				return false
			}
		} else if !(c.is_letter() || c.is_digit() || c in [`_`, `.`, `?`, `&`]) {
			return false
		}
	}
	return depth == 0
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
	if t.has_u64_bits(expr) {
		return 'u64'
	}
	if t.has_large_integer(expr) {
		return large_integer_type
	}
	reference_annotation := get_v_annotation(expr)
	if reference_annotation.contains('u64') {
		return t.map_type(reference_annotation)
	}
	if reference_annotation.contains('pyrt.ListRef[') || (expr is Attribute && (expr as Attribute).attr == 'items' && reference_annotation.starts_with('[]')) {
		return reference_annotation
	}
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
			if t.var_types[expr.id] in ['Py2vNumber', '[]Py2vNumber'] {
				return t.var_types[expr.id]
			}
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
			if expr.op is Div && (left_type == 'Py2vNumber' || right_type == 'Py2vNumber') {
				return 'f64'
			}
			if (expr.op is Sub || expr.op is Add || expr.op is Mult)
				&& (left_type == 'Py2vNumber' || right_type == 'Py2vNumber') {
				return if left_type in ['float', 'f64'] || right_type in ['float', 'f64'] {
					'f64'
				} else {
					'Py2vNumber'
				}
			}
			if right_type == 'string' {
				return 'string'
			}
			// True division of two ints gives a float
			if expr.op is Div && is_v_int_type(t.division_operand_type(expr.left, left_type))
				&& is_v_int_type(t.division_operand_type(expr.right, right_type)) {
				return 'f64'
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
			if expr.func is Name {
				if expr.func.id == 'round' && expr.args.len == 2 && expr.keywords.len == 0
					&& t.infer_expr_type(expr.args[0]) == 'Py2vNumber' {
					return 'Py2vNumber'
				}
				if t.sum_may_return_integer_zero(expr) { return 'Py2vNumber' }
				if expr.func.id == 'sum' && expr.args.len > 0 && 'sum' !in t.module_functions
					&& !t.is_bound_in_scope('sum') {
					kind := python_numeric_arg_list_kind(t, expr.args[0])
					if kind == 'uniform_sum_array' && expr.args.len == 1 && expr.keywords.len == 0 {
						return 'Py2vNumber'
					}
					if kind == 'empty' {
						if start := python_sum_start(expr) { return t.infer_expr_type(start) }
						return 'int'
					}
					if kind in ['float', 'maybe_float'] { return 'f64' }
				}
				if t.recursive_int_results[expr.func.id] { return 'int' }
				if t.numeric_array_results[expr.func.id] || t.sum_array_results[expr.func.id] {
					return '[]Py2vNumber'
				}
				if t.numeric_scalar_results[expr.func.id] { return 'Py2vNumber' }
				if expr.func.id == 'abs' && expr.args.len == 1 && t.infer_expr_type(expr.args[0]) == 'Py2vNumber' {
					return 'Py2vNumber'
				}
			}
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
					'str', 'bin' { return 'string' }
					'int' { return 'int' }
					'float' { return 'f64' }
					'bool' { return 'bool' }
					'len' { return 'int' }
					'input' {
						return 'string'
					}
					'map' {
						// `map(str, xs)` and its like: the class names the element type
						if expr.args.len == 2 && expr.args[0] is Name {
							match (expr.args[0] as Name).id {
								'str' { return '[]string' }
								'int' { return '[]int' }
								'float' { return '[]f64' }
								else {}
							}
						}
						return t.func_return_types[fn_name]
					}
					else {
						return t.func_return_types[fn_name]
					}
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
		ListComp {
			if expr.elt is IfExp && t.is_numeric_choice(expr.elt) {
				return '[]Py2vNumber'
			}
			return ''
		}
		Subscript {
			if t.infer_expr_type(expr.value) == '[]Py2vNumber' {
				return if expr.slice is Slice { '[]Py2vNumber' } else { 'Py2vNumber' }
			}
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
		IfExp {
			if t.is_numeric_choice(expr) {
				return if t.emit_pub { 'pyrt.Value' } else { 'Py2vNumber' }
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
			if constructor := t.resolve_init_constructor(expr.func) {
				params := init_positional_parameters(constructor)
				for i, arg in expr.args {
					if i < params.len && params[i].arg in constructor.init.mutable_vars && arg is Name {
						t.extra_mut_vars[arg.id] = true
					}
				}
				for keyword in expr.keywords {
					if name := keyword.arg {
						if name in constructor.init.mutable_vars && keyword.value is Name {
							t.extra_mut_vars[(keyword.value as Name).id] = true
						}
					}
					t.prescan_mut_call_args_in_expr(keyword.value)
				}
			}
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
	if name in t.local_idents || name in t.renamed_idents || t.is_bound_in_scope(name) {
		return false
	}
	if t.imported_modules[name] or { false } {
		return true
	}
	return t.import_prefixes[name] or { false }
}

// seed_class_by_name registers a class the scan saw under its bare name, so a
// qualified reference such as `cache.Blocker(...)` can lower to a struct
// literal even though this module never emitted the class itself.
pub fn (mut t VTranspiler) seed_class_by_name(name string) {
	if name in t.known_classes {
		return
	}
	found := t.registry.class_named(name)
	if found.fields.len == 0 && found.bases.len == 0 {
		return
	}
	t.known_classes[name] = found.fields
	t.class_direct_fields[name] = found.fields
	t.class_base_names[name] = found.bases
	t.imported_classes[name] = found.fields
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
		bases := t.registry.class_bases(module_dotted, name)
		// A class that declares no fields of its own is still a class when it
		// embeds a base: `class B(A)` where `A` holds the state. Registering it
		// is what lets `B(...)` become a struct literal that fills the base.
		if fields.len > 0 || bases.len > 0 {
			if name !in t.imported_classes {
				t.imported_classes[name] = fields
			}
			t.known_classes[name] = fields
			if bases.len > 0 {
				t.class_direct_fields[name] = fields
				t.class_base_names[name] = bases
			}
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
					if recv_type != '' && t.mut_receiver_methods['${recv_type.trim_left('?&')}_${attr.attr}'] {
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

// ctor_struct_literal writes the call `node` that constructs class `class_name`
// as the struct literal `emitted_ctor{...}`. `vargs` are its positional
// arguments, already translated; they fill the fields in declaration order.
fn (mut t VTranspiler) ctor_struct_literal(emitted_ctor string, class_name string, node Call, vargs []string) string {
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
	fields := t.known_classes[class_name]
	for i, arg in vargs {
		if i < fields.len {
			field_vals[fields[i]] = arg
		}
	}

	direct_fields := t.class_direct_fields[class_name] or { fields.clone() }
	base_names := t.class_base_names[class_name] or { []string{} }

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

// constructor_name returns the class a call constructs, or '' when the callee is
// an ordinary function. Only a real class records a variable type here; treating
// `gap = max(...)` as a constructor would clobber the inferred type of `gap`.
fn (t VTranspiler) constructor_name(call Call) string {
	if constructor := t.resolve_init_constructor(call.func) {
		return constructor.class_name
	}
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

// hoist_block_fns lifts function definitions out of nested blocks in `stmts`,
// appending their V code to `out`. Statements are rewritten in place through the
// returned list.
pub fn (mut t VTranspiler) hoist_block_fns(stmts []Stmt, mut out []string, in_block bool) []Stmt {
	mut result := []Stmt{}
	for index, stmt in stmts {
		// A local function returned by its defining branch can stay a closure.
		if in_block && stmt is FunctionDef && stmt.is_nested && index + 2 == stmts.len
			&& stmts[index + 1] is Return {
			tail := stmts[index + 1] as Return
			if value := tail.value {
				if value is Name && value.id == stmt.name {
					result << stmt
					continue
				}
			}
		}
		result << t.hoist_in_stmt(stmt, mut out, in_block)
	}
	return result
}

fn (mut t VTranspiler) hoist_in_stmt(stmt Stmt, mut out []string, in_block bool) Stmt {
	// Lift the definition out of the block. V has no way to declare a function
	// inside a nested block, so the block keeps a `pass` in its place.
	//
	// A closure that captures `nonlocal` variables cannot be hoisted: it has to
	// stay an inline closure so it captures by reference.
	if stmt is FunctionDef {
		fd := stmt as FunctionDef
		if fd.is_nested && (!in_block || fd.capture_names.len > 0 || fd.is_recursive
			|| fd.args.defaults.any(it !is Constant) || fd.decorator_list.len > 0) {
			return stmt
		}
		for inner in fd.body {
			if inner is Nonlocal {
				return stmt
			}
		}
		out << t.visit_function_def(fd)
		return Stmt(Pass{})
	}
	if stmt is AsyncFunctionDef {
		fd := stmt as AsyncFunctionDef
		if fd.is_nested && (!in_block || fd.capture_names.len > 0 || fd.is_recursive
			|| fd.args.defaults.any(it !is Constant) || fd.decorator_list.len > 0) {
			return stmt
		}
		out << t.visit_async_function_def(fd)
		return Stmt(Pass{})
	}
	// A class under any enclosing block has to move: V cannot declare a struct
	// or attach a method inside a block, whether that block is module level or a
	// function body, and portage guards whole classes on feature probes such as
	// `if HAVE_XATTR:`.
	if stmt is ClassDef {
		out << t.visit_class_def(stmt as ClassDef)
		return Stmt(Pass{})
	}
	match stmt {
		If {
			s := stmt as If
			return Stmt(If{
				test:                   s.test
				lower_condition_walrus: s.lower_condition_walrus
				body:                   t.hoist_block_fns(s.body, mut out, true)
				orelse:                 t.hoist_block_fns(s.orelse, mut out, true)
				loc:                    s.loc
				level:                  s.level
			})
		}
		For {
			s := stmt as For
			return Stmt(For{
				target: s.target
				iter:   s.iter
				body:   t.hoist_block_fns(s.body, mut out, true)
				orelse: t.hoist_block_fns(s.orelse, mut out, true)
				loc:    s.loc
				level:  s.level
			})
		}
		While {
			s := stmt as While
			return Stmt(While{
				test:   s.test
				body:   t.hoist_block_fns(s.body, mut out, true)
				orelse: t.hoist_block_fns(s.orelse, mut out, true)
				loc:    s.loc
				level:  s.level
			})
		}
		With {
			s := stmt as With
			return Stmt(With{
				items: s.items
				body:  t.hoist_block_fns(s.body, mut out, true)
				loc:   s.loc
			})
		}
		AsyncWith {
			s := stmt as AsyncWith
			return Stmt(AsyncWith{
				items: s.items
				body:  t.hoist_block_fns(s.body, mut out, true)
				loc:   s.loc
			})
		}
		AsyncFor {
			s := stmt as AsyncFor
			return Stmt(AsyncFor{
				target: s.target
				iter:   s.iter
				body:   t.hoist_block_fns(s.body, mut out, true)
				orelse: t.hoist_block_fns(s.orelse, mut out, true)
				loc:    s.loc
				level:  s.level
			})
		}
		Try {
			s := stmt as Try
			mut handlers := []ExceptHandler{}
			for h in s.handlers {
				handlers << ExceptHandler{
					typ:     h.typ
					classes: h.classes
					name:    h.name
					body:    t.hoist_block_fns(h.body, mut out, true)
					loc:     h.loc
				}
			}
			return Stmt(Try{
				body:               t.hoist_block_fns(s.body, mut out, true)
				handlers:           handlers
				orelse:             t.hoist_block_fns(s.orelse, mut out, true)
				finalbody:          t.hoist_block_fns(s.finalbody, mut out, true)
				guard:              s.guard
				loc:                s.loc
				is_exception_group: s.is_exception_group
			})
		}
		else {
			return stmt
		}
	}
}

// hoist_module_fns lifts function definitions declared inside module-level
// blocks out to module scope, where V requires them.
pub fn (mut t VTranspiler) hoist_module_fns(stmts []Stmt, mut out []string) []Stmt {
	// Top-level statements are already in the right place; only recurse into
	// blocks, where a nested `fn` would be illegal in V.
	mut result := []Stmt{}
	for stmt in stmts {
		match stmt {
			If {
				s := stmt as If
				result << Stmt(If{
					test:                   s.test
					lower_condition_walrus: s.lower_condition_walrus
					body:                   t.hoist_in_stmt_list(s.body, mut out)
					orelse:                 t.hoist_in_stmt_list(s.orelse, mut out)
					loc:                    s.loc
					level:                  s.level
				})
			}
			For {
				s := stmt as For
				result << Stmt(For{
					target: s.target
					iter:   s.iter
					body:   t.hoist_in_stmt_list(s.body, mut out)
					orelse: t.hoist_in_stmt_list(s.orelse, mut out)
					loc:    s.loc
					level:  s.level
				})
			}
			While {
				s := stmt as While
				result << Stmt(While{
					test:   s.test
					body:   t.hoist_in_stmt_list(s.body, mut out)
					orelse: t.hoist_in_stmt_list(s.orelse, mut out)
					loc:    s.loc
					level:  s.level
				})
			}
			Try {
				s := stmt as Try
				mut handlers := []ExceptHandler{}
				for h in s.handlers {
					handlers << ExceptHandler{
						typ:     h.typ
						classes: h.classes
						name:    h.name
						body:    t.hoist_in_stmt_list(h.body, mut out)
						loc:     h.loc
					}
				}
				result << Stmt(Try{
					body:               t.hoist_in_stmt_list(s.body, mut out)
					handlers:           handlers
					orelse:             t.hoist_in_stmt_list(s.orelse, mut out)
					finalbody:          t.hoist_in_stmt_list(s.finalbody, mut out)
					guard:              s.guard
					loc:                s.loc
					is_exception_group: s.is_exception_group
				})
			}
			else {
				result << stmt
			}
		}
	}
	return result
}

// hoist_in_stmt_list lifts definitions out of a block's statement list.
fn (mut t VTranspiler) hoist_in_stmt_list(stmts []Stmt, mut out []string) []Stmt {
	mut result := []Stmt{}
	for stmt in stmts {
		result << t.hoist_in_stmt(stmt, mut out, true)
	}
	return result
}
