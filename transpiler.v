module main

const max_generated_line_len = 121

pub struct VTranspiler {
mut:
	tmp_gen TmpVarGen
	usings  []string
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
	current_class_name   string
	current_classmethod  bool
	escaped_identifiers  map[string]bool
	extra_mut_vars       map[string]bool
	func_defaults        map[string][]string
	func_param_count     map[string]int
	call_signatures      map[string]FunctionDef
	default_import_names map[string]bool
	call_before_def      map[string]bool
	func_return_types    map[string]string
	// Methods whose receiver must be `mut` in V, keyed ClassName_method.
	mut_receiver_methods        map[string]bool
	generated_code_has_any_type bool
	global_vars                 map[string]bool
	has_global_decl             bool
	mut_param_indices           map[string][]int
	generator_yield_types       map[string]string   // generator function -> its channel element type
	func_param_types            map[string][]string // module function -> the V types of its parameters
	var_types                   map[string]string
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
	// Project translation state. `emit_pub` makes top-level symbols visible
	// across V modules; `registry` maps Python module paths to V modules;
	// `current_dotted` is this module's Python dotted path.
	// current_is_package is true when that path names a package rather than a
	// module, which is what a relative import resolves against.
	emit_pub       bool
	registry       ModuleRegistry
	current_dotted string
	// fn_returns_result: the function being emitted returns a V result (`!T`).
	fn_returns_result bool
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
	loop_idents map[string]bool
	// loop_breaks has one entry per loop whose body is being emitted, innermost
	// last, so a `break` knows whether it leaves a loop that has an `else`.
	loop_breaks []LoopBreak
	// scope_idents holds every V name bound so far in the function being
	// emitted, its parameters included. V rejects a `for` variable that
	// shadows any of them, not only an enclosing iteration variable, so Python's
	// habit of rebinding a parameter inside a loop has to be given a fresh name.
	scope_idents map[string]bool
	// param_idents holds the parameters of the function being emitted. A loop
	// that rebinds one cannot assign to it, so it only gets a fresh name.
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
		import_prefixes:             map[string]bool{}
		loop_idents:                 map[string]bool{}
		scope_idents:                map[string]bool{}
		unmapped_modules:            map[string]bool{}
		unmapped_calls:              []string{}
		exception_handlers:          []string{}
		renamed_idents:              map[string]string{}
		module_aliases:              map[string]string{}
		imported_classes:            map[string][]string{}
		submodule_aliases:           map[string]string{}
		local_idents:                map[string]string{}
		module_idents:               map[string]string{}
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
	return name
}

// visit_module renders a whole Python module: constants, imports, structs and
// functions, in the order V requires them.
pub fn (mut t VTranspiler) visit_module(node Module) string {
	t.prepare_init_constructors(node)
	mut bindings := map[string]int{}
	mut calls := []BindingCall{}
	count_call_bindings(node, mut bindings, mut calls, false)
	t.default_import_names = imported_default_names(node, bindings)
	t.prepare_local_default_names(node)
	mut signatures := map[string]FunctionDef{}
	mut module_defs := map[string][]FunctionDef{}
	for stmt in node.body {
		if stmt is FunctionDef {
			module_defs[stmt.name] << stmt
			// In a project other files can call the function; this pass cannot see those calls.
			if !t.emit_pub && bindings[stmt.name] == 1 && bindings['*'] == 0 && stmt.decorator_list.len == 0 {
				signatures[stmt.name] = stmt
			}
		}
	}
	t.call_signatures = signatures
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
				if _ := t.bind_module_call(call) {} else { rejected = true }
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

	// Any type alias must be first among type_decls. A package is merged into
	// one V module per subpackage, so the alias belongs to that module and only
	// the first file of it declares it.
	// Code that calls the runtime imports it, whether or not it also names `Any`.
	for part in [type_decls, struct_decls, func_decls, main_fn_body, [main_fn_override]] {
		if part.any(it.contains('pyrt.')) {
			t.add_using('pyrt')
			break
		}
	}
	// A type that reached the output through a type table also needs the alias.
	if !t.generated_code_has_any_type {
		for part in [type_decls, struct_decls, func_decls, main_fn_body, [main_fn_override]] {
			if part.any(mentions_word(it, 'Any')) {
				t.generated_code_has_any_type = true
				break
			}
		}
	}
	if t.generated_code_has_any_type && !t.registry.any_declared_in[t.module_name] {
		t.registry.any_declared_in[t.module_name] = true
		// A value whose type is not known is the runtime's value. Its operators are
		// declared on the alias here: V resolves an operator on a sum type only when it
		// is declared in the module that uses it.
		t.add_using('pyrt')
		type_decls.prepend(any_operators)
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
		for i, line in main_fn_body {
			decl := module_scope_decl(main_fn_stmts[i], line, t.module_idents)
			library_decls << if decl.starts_with('const ') { 'pub ' + decl } else { decl }
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
	for f in nested_fndefs {
		func_decls << f
	}
	if t.uses_py2v_format && !t.registry.py2v_format_declared_in[t.module_name] {
		t.registry.py2v_format_declared_in[t.module_name] = true
		func_decls << py2v_format_helper
	}
	// A run-time helper is declared in the first file of a V module that asks for it.
	for kind in t.helpers_used {
		key := '${t.module_name}.${kind}'
		if !t.registry.helper_declared[key] {
			t.registry.helper_declared[key] = true
			func_decls << runtime_helper_declaration(kind, t.runtime_helper_name(kind))
		}
	}
	if func_decls.len > 0 {
		parts << func_decls.join('\n\n')
	}
	if main_str != '' {
		parts << main_str
	}

	return parts.join('\n\n') + '\n'
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

// runtime_helper_declaration returns the V source of the run-time helper `kind`.
fn runtime_helper_declaration(kind string, name string) string {
	return match kind {
		'isinstance_empty' {
			'fn ${name}[T](value T) bool {\n\t_ = value\n\treturn false\n}'
		}
		'assign_expr' {
			'fn ${name}[T](target &T, value T) T {\n' +
				'\tunsafe { *target = value }\n\treturn value\n}'
		}
		'divmod_int', 'divmod_float', 'divmod_value' {
			typ := if kind == 'divmod_int' {
				'int'
			} else if kind == 'divmod_float' {
				'f64'
			} else {
				'pyrt.Value'
			}
			values := if kind == 'divmod_int' {
				'pyrt.to_int(q), pyrt.to_int(r)'
			} else if kind == 'divmod_float' {
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
		'generic_mod' {
			'fn ${name}[T](a T, b T) T {\n' +
				'\t\$if T is \$float {\n' +
				"\t\tif b == 0 { panic('float modulo by zero') }\n" +
				'\t\tmut r := math.fmod(f64(a), f64(b))\n' +
				'\t\tif r != 0 {\n' +
				'\t\t\tif (r < 0) != (b < 0) { r += f64(b) }\n' +
				'\t\t} else { r = math.copysign(0.0, f64(b)) }\n' +
				'\t\treturn T(r)\n' +
				'\t} \$else \$if T is \$int {\n' +
				'\t\treturn math.modulo_floored(a, b)\n' +
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
		'true_div' {
			'fn ${name}(a f64, b f64) f64 {\n' + '\tif b == 0 {\n' +
				"\t\tpanic('division by zero')\n" + '\t}\n' + '\treturn a / b\n' + '}'
		}
		'bin' {
			// Python's bin(): the sign comes before the `0b` prefix.
			'fn ${name}(n i64) string {\n' + '\tif n < 0 {\n' +
				"\t\treturn '-0b' + strconv.format_int(-n, 2)\n" + '\t}\n' +
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
		mut prelude := []string{}
		bound := t.bind_chain_middle(val, mut prelude)
		prelude << 'return ${t.visit_expr(bound)}'
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
		Break { return t.visit_break() }
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
	saved_breaks := t.loop_breaks.clone()
	saved_escaped := t.escaped_identifiers.clone()
	saved_condition_vars := t.condition_walrus_vars
	saved_condition_types := t.condition_walrus_types
	saved_condition_initial := t.condition_walrus_initial
	saved_condition_order := t.condition_walrus_order
	saved_return_count := t.current_return_count
	saved_result := t.fn_returns_result
	saved_init_aliases := t.init_import_aliases.clone()
	saved_init_captures := t.init_capture_locals.clone()
	defer {
		t.var_types = saved_types
		t.local_idents = saved_locals
		t.local_idents[node.name] = name
		t.scope_idents = saved_scope
		t.scope_idents[name] = true
		t.param_idents = saved_params
		t.renamed_idents = saved_renames
		t.loop_idents = saved_loops
		t.loop_prelude = saved_loop_prelude
		t.loop_breaks = saved_breaks
		t.escaped_identifiers = saved_escaped
		t.condition_walrus_vars = saved_condition_vars
		t.condition_walrus_types = saved_condition_types
		t.condition_walrus_initial = saved_condition_initial
		t.condition_walrus_order = saved_condition_order
		t.current_return_count = saved_return_count
		t.fn_returns_result = saved_result
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
		if typ.contains('Any') { t.generated_code_has_any_type = true }
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
	t.scope_idents = map[string]bool{}
	for py_name, _ in capture_locals { t.scope_idents[escape_local_ident(py_name)] = true }
	t.param_idents = map[string]bool{}
	t.renamed_idents = map[string]string{}
	t.loop_idents = map[string]bool{}
	t.loop_prelude = []string{}
	t.loop_breaks = []LoopBreak{}
	t.escaped_identifiers = map[string]bool{}
	t.condition_walrus_vars = map[string]bool{}
	t.condition_walrus_types = map[string]string{}
	t.condition_walrus_initial = map[string]string{}
	t.condition_walrus_order = []string{}
	t.current_return_count = 0
	t.fn_returns_result = false
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
		if typ.contains('Any') { t.generated_code_has_any_type = true }
		t.local_idents[arg.arg] = local
		t.scope_idents[local] = true
		t.param_idents[arg.arg] = true
		t.var_types[arg.arg] = typ
		mut incoming := local
		if arg.arg in node.mutable_vars {
			if typ in v_value_param_types {
				incoming = t.new_tmp('${arg.arg}_in')
				copies << 'mut ${local} := ${incoming}'
			} else {
				incoming = 'mut ${local}'
				mut_indices << i
			}
		}
		declarations << '${incoming} ${typ}'
		param_types << typ
	}
	if kwarg := node.args.kwarg {
		local := escape_local_decl(kwarg.arg)
		t.local_idents[kwarg.arg] = local
		declarations << '${local} map[string]Any'
		t.generated_code_has_any_type = true
	}
	if node.is_generator {
		typ := t.infer_generator_yield_type(node.body)
		declarations << 'ch chan ${typ}'
		t.generator_yield_types[node.name] = typ
	}
	if vararg := node.args.vararg {
		local := escape_local_decl(vararg.arg)
		mut typ := t.typename_from_annotation(vararg.annotation)
		if typ == '' {
			typ = 'Any'
			t.generated_code_has_any_type = true
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
		if ret.contains('Any') { t.generated_code_has_any_type = true }
		if ret.starts_with('(') { t.current_return_count = ret.count(',') + 1 }
	}
	t.func_return_types[node.name] = ret
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
	saved_nested_generators := t.generator_yield_types.clone()
	defer {
		t.func_defaults = saved_nested_defaults
		t.func_param_count = saved_nested_counts
		t.func_param_types = saved_nested_params
		t.func_return_types = saved_nested_returns
		t.mut_param_indices = saved_nested_mut
		t.generator_yield_types = saved_nested_generators
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
	if !node.is_class_method {
		t.init_import_aliases.delete(node.name)
	}
	if !node.is_class_method {
		renamed := t.emitted_fn_name(node.name)
		if renamed != node.name {
			return t.visit_function_def(FunctionDef{
				...node
				name: renamed
			})
		}
	}
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
	saved_escaped_identifiers := t.escaped_identifiers.clone()
	t.escaped_identifiers = map[string]bool{}
	saved_local_idents := t.local_idents.clone()
	t.local_idents = map[string]string{}
	saved_current_class := t.current_class_name
	saved_classmethod := t.current_classmethod
	saved_returns_result := t.fn_returns_result
	t.fn_returns_result = node.raises && !node.is_class_method
	defer {
		t.fn_returns_result = saved_returns_result
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
	t.scope_idents = map[string]bool{}
	saved_param_idents := t.param_idents
	t.param_idents = map[string]bool{}

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
	// @classmethod / @staticmethod: emit as free function named ClassName_funcname
	if node.is_class_method && node.decorator_kind in ['classmethod', 'staticmethod'] {
		member := if node.dunder_op.starts_with('py2v_overload_') { emit_name } else { node.name }
		emit_name = '${emitted_class_name(node.class_name)}_${member}'
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
	for arg in positional_args {
		if arg.arg == 'self' {
			continue
		}
		// Skip `cls` for @classmethod
		if arg.arg == 'cls' && node.decorator_kind == 'classmethod' {
			continue
		}
		// A parameter is already bound, so a `for` variable of the same name
		// must take a fresh one.
		t.scope_idents[escape_local_ident(arg.arg)] = true
		t.param_idents[arg.arg] = true

		mut typename := ''
		if ann := arg.annotation {
			typename = t.typename_from_annotation(*ann)
		}
		// A parameter the frontend could only type by inference, for example one
		// that exists solely to fill an annotated field.
		if typename == '' && arg.v_annotation != '' {
			typename = t.map_type(arg.v_annotation)
		}

		// Python commonly leaves the operand of a comparison unannotated, which
		// would otherwise become `Any`; V needs the receiver type there.
		if typename == '' && is_binop_dunder && node.is_class_method {
			typename = emitted_receiver_type
		}

		mut arg_name := escape_local_decl(arg.arg)
		t.local_idents[arg.arg] = arg_name
		// Track identifiers escaped due to built-in type name conflicts
		if arg.arg in v_builtin_types {
			t.escaped_identifiers[arg.arg] = true
		}
		// Check if this argument is mutable
		if arg.arg in node.mutable_vars {
			optional_value := !node.is_class_method && arg.arg !in node.condition_walrus_names
				&& is_optional_value_type(typename)
			if typename in v_value_param_types && arg.arg in node.condition_walrus_names {
				// The walrus lowering copies this parameter itself.
			} else if typename in v_value_param_types || optional_value {
				// Rebinding a number, string or bool parameter is local in Python, and V
				// has no `mut` for these or their options: it arrives under another name and the
				// body starts with a mutable local that has the source's name.
				incoming := t.new_tmp('${arg.arg}_in')
				param_copies << 'mut ${arg_name} := ${incoming}'
				arg_name = incoming
			} else {
				arg_name = 'mut ${arg_name}'
				mut_indices << param_idx
			}
		}

		if typename == '' {
			// V functions require explicit parameter types.
			typename = 'Any'
			t.generated_code_has_any_type = true
		} else {
			// A single uppercase letter is a generic, alone (`T`) or inside a type (`[]T`)
			for letter in generic_letters(typename) {
				if letter !in generics {
					generics << letter
				}
			}
		}

		args_strs << '${arg_name} ${typename}'
		if !node.is_class_method {
			t.func_param_types[node.name] << typename
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
		t.scope_idents[escape_local_ident(kwonly.arg)] = true
		t.param_idents[kwonly.arg] = true
		mut kwtype := 'Any'
		t.generated_code_has_any_type = true
		if ann := kwonly.annotation {
			kwtype = t.typename_from_annotation(*ann)
		}
		t.var_types[kwonly.arg] = kwtype
		if kwonly.arg in node.mutable_vars {
			if kwtype in v_value_param_types {
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
		t.generated_code_has_any_type = true
		// No trailing comment: a `//` after the last parameter would swallow the
		// opening brace of the function body.
		local := escape_local_decl(kwarg.arg)
		t.local_idents[kwarg.arg] = local
		t.scope_idents[escape_local_ident(kwarg.arg)] = true
		t.param_idents[kwarg.arg] = true
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
			t.generated_code_has_any_type = true
		} else {
			typename = '...' + typename
		}
		local := escape_local_decl(vararg.arg)
		t.local_idents[vararg.arg] = local
		t.scope_idents[escape_local_ident(vararg.arg)] = true
		t.param_idents[vararg.arg] = true
		t.var_types[vararg.arg] = '[]' + typename.trim_left('.')
		args_strs << '${local} ${typename}'
	}

	// For generator functions, add channel parameter
	if node.is_generator {
		yield_type := t.infer_generator_yield_type(node.body)
		t.generator_yield_types[node.name] = yield_type
		args_strs << 'ch chan ${yield_type}'
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
	t.current_return_count = 0
	if !node.is_void && !node.is_generator && node.name != '__init__' {
		if ret := node.returns {
			ret_type := v_return_type(t.typename_from_annotation(*ret))
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

	// A nested definition's signature belongs to this lexical scope. Keep the
	// current function's metadata, and discard metadata introduced by its body.
	saved_nested_defaults := t.func_defaults.clone()
	saved_nested_counts := t.func_param_count.clone()
	saved_nested_params := t.func_param_types.clone()
	saved_nested_returns := t.func_return_types.clone()
	saved_nested_mut := t.mut_param_indices.clone()
	saved_nested_generators := t.generator_yield_types.clone()
	defer {
		t.func_defaults = saved_nested_defaults
		t.func_param_count = saved_nested_counts
		t.func_param_types = saved_nested_params
		t.func_return_types = saved_nested_returns
		t.mut_param_indices = saved_nested_mut
		t.generator_yield_types = saved_nested_generators
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
	if node.raises && !node.is_class_method {
		// The fallible body under `<name>_py`, and the old name as the wrapper that ends
		// the program on an error, for every caller that does not propagate.
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
			call := '${emit_name}_py(${forwarded.join(', ')}) or { pyrt.fail(err) }'
			wrapper_body := if ret == '' { call } else { 'return ${call}' }
			t.add_using('pyrt')
			func_code = '${dunder_comment}${head} ${emit_name}_py${generic_list}(${args_strs.join(', ')}) !${ret} {\n${body}\n}\n\n' +
				'${head} ${params} ${ret} {\n\t${wrapper_body}\n}'
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
	t.escaped_identifiers = saved_escaped_identifiers.clone()
	t.local_idents = saved_local_idents.clone()
	t.init_import_aliases = saved_init_aliases.clone()
	t.init_capture_locals = saved_init_captures.clone()
	t.current_classmethod = saved_classmethod

	// A nested function must not inherit the enclosing function's return arity.
	t.current_return_count = saved_return_count
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
				t.generated_code_has_any_type = true
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
		mut field_annotations := map[string]Expr{}
		for stmt in node.body {
			if stmt is AnnAssign && stmt.target is Name && has_class_annotation(stmt.annotation) {
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
				t.generated_code_has_any_type = true
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
	// Record what this assignment binds, so a later `for` over the same Python
	// name is given a fresh V variable instead of shadowing it. Whether a name
	// was already bound has to be sampled before this statement binds anything,
	// or a first declaration would look like a rebind of itself.
	mut was_bound := map[string]bool{}
	for target in node.targets {
		if target is Name {
			was_bound[(target as Name).id] = t.is_bound_in_scope((target as Name).id)
		}
	}
	for target in node.targets {
		if target is Name {
			t.note_scope_binding((target as Name).id)
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
							t.generated_code_has_any_type = true
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
fn (mut t VTranspiler) modulo_expression(left Expr, right Expr, a string, b string) string {
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
	if (is_v_int_type(la) || la == 'bool') && (is_v_int_type(ra) || ra == 'bool') {
		t.add_using('math')
		lhs := if la == 'bool' { 'int(${a})' } else { a }
		rhs := if ra == 'bool' { 'int(${b})' } else { b }
		return 'math.modulo_floored(${lhs}, ${rhs})'
	}
	if la == '' || ra == '' || generic_letters(la).len > 0 || generic_letters(ra).len > 0 {
		t.add_using('math')
		return '${t.runtime_helper('generic_mod')}(${a}, ${b})'
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
		lines << 'mut ${container} := &(${t.visit_expr(*sub.value)})'
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
		target = '${receiver}.${attr.attr}'
	} else if node.target !is Name {
		return 'py2v_unsupported_modulo_assignment_target()'
	}
	old := t.new_tmp('old')
	lines << '${old} := ${target}'
	value := t.visit_expr(node.value)
	if op_type == 'Mod' {
		lines << '${target} = ${t.modulo_expression(*node.target, node.value, old, value)}'
	} else {
		lines << t.visit_aug_assign_once(node, op_type, target, value)
	}
	code := lines.join('\n')
	if node.target is Name && target.starts_with('(*') {
		return 'unsafe {\n${t.indent_code(code, 1)}\n}'
	}
	return code
}

// visit_aug_assign emits V code for an AugAssign statement.
pub fn (mut t VTranspiler) visit_aug_assign(node AugAssign) string {
	op_type := get_op_type(node.op)
	if op_type == 'Mod' { return t.captured_aug_assign(node, op_type) }
	// `**=` and `//=` become `target = f(target, val)`, which names the target twice. Python
	// evaluates the target's indices once, in the order they are written, before the
	// right-hand side. So when an index or slice bound is computed (`x[f()] **= 2`) or the
	// right-hand side could run code (`x[i] **= g()`), every index and bound of a target that
	// starts from a name is computed into a temp first, in that order: a name too, since a
	// later call could change it, and a negative literal as `x.len - n`, since a later call
	// could change the length. Non-negative literals stay inline. Reading the containers the
	// indices select (`grid[i]` in `grid[f()][g()]`) still comes after all of them.
	mut prelude := []string{}
	target_node := if op_type in ['Pow', 'FloorDiv'] && can_hoist_indices(*node.target)
		&& (has_computed_index(*node.target) || !t.runs_no_code(node.value)) {
		t.index_once(*node.target, mut prelude)
	} else {
		*node.target
	}
	target := t.visit_expr(target_node)
	val := t.visit_expr(node.value)
	mut code := t.visit_aug_assign_once(node, op_type, target, val)
	if node.target is Name && target.starts_with('(*') {
		code = 'unsafe {\n${t.indent_code(code, 1)}\n}'
	}
	if prelude.len > 0 {
		return prelude.join('\n') + '\n' + code
	}
	return code
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
fn (mut t VTranspiler) visit_aug_assign_once(node AugAssign, op_type string, target string, val string) string {
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
			return '${target} = math.floor(${target} / ${paren_right(val, 5)})'
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
	return '${target} ${op_sym}= ${val}'
}

// visit_ann_assign emits V code for an AnnAssign statement.
pub fn (mut t VTranspiler) visit_ann_assign(node AnnAssign) string {
	was_bound := node.target is Name && t.is_bound_in_scope(node.target.id)
	if node.target is Name { t.note_scope_binding(node.target.id) }
	target := t.visit_expr(node.target)
	type_str := t.typename_from_annotation(*node.annotation)

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

		return '${kw}${target} ${op} ${val_str}'
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
	ann := arg.annotation or { return false }
	expr := *ann
	if expr is Name {
		return expr.id in ['int', 'float', 'str', 'bool']
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

// mentions_word tells whether `word` stands in `code` as a whole identifier.
fn mentions_word(code string, word string) bool {
	mut from := 0
	for {
		i := code.index_after(word, from) or { return false }
		before := if i > 0 { code[i - 1] } else { u8(` `) }
		end := i + word.len
		after := if end < code.len { code[end] } else { u8(` `) }
		if !(before.is_letter() || before.is_digit() || before == `_` || before == `.`)
			&& !(after.is_letter() || after.is_digit() || after == `_`) {
			return true
		}
		from = end
	}
	return false
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
	mut taken := map[string]bool{}
	for k, _ in pending {
		taken[k] = true
	}
	// A plain `for {}` binds no iteration variable, so the candidate name can
	// be declared in the body without V reading it as a redefinition.
	mut n := 0
	for {
		candidate := if n == 0 { '${name}_' } else { '${name}_${n}' }
		if !(candidate in t.loop_idents) && !(candidate in taken) {
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

// note_scope_binding records the V spelling a Python name is bound to in the
// function currently being emitted.
fn (mut t VTranspiler) note_scope_binding(py_name string) {
	v := t.renamed_idents[py_name] or { escape_local_ident(py_name) }
	t.scope_idents[v] = true
}

// is_bound_in_scope reports whether `py_name` is already a parameter or local of
// the function being emitted.
fn (t VTranspiler) is_bound_in_scope(py_name string) bool {
	return t.scope_idents[escape_local_ident(py_name)]
}

// bind_op returns the operator that binds `v_name`. V rejects a second
// declaration of a name that is already bound in the function, and a Python
// loop target that shadows an existing name rebinds that same variable rather
// than introducing a new one, so this has to be an assignment.
fn (t VTranspiler) bind_op(v_name string) string {
	return if t.scope_idents[v_name] { '=' } else { ':=' }
}

// visit_for emits V code for a For loop.
pub fn (mut t VTranspiler) visit_for(node For) string {
	saved_renames := t.renamed_idents.clone()
	// V rejects reusing an iteration variable name in a nested loop, and
	// Python allows it freely. Bind the inner loop to a fresh name and record
	// the rename so the body refers to the variable it actually declares.
	mut rename := map[string]string{}
	for name in for_target_names(node.target) {
		// V rejects a `for` variable that shadows anything already bound in the
		// enclosing scope, which in Python is an ordinary way to rebind a name.
		if name in t.loop_idents || escape_local_ident(name) in t.scope_idents {
			fresh := if t.condition_walrus_vars[name] {
				t.new_tmp('walrus_iter')
			} else {
				t.fresh_loop_ident(name, rename)
			}
			// Python rebinds the existing local on every iteration, and code after
			// the loop reads its last value. Only a mutable local can take that
			// assignment: not a parameter, and not an enclosing loop variable.
			if name !in t.loop_idents && name !in t.param_idents && name !in t.renamed_idents
				&& !t.condition_walrus_vars[name] && for_target_is_mutable(node.target, name) {
				t.loop_prelude << '${escape_local_ident(name)} = ${fresh}'
			}
			rename[name] = fresh
		}
	}
	// Every name this loop binds is unbound again on the way out, so a later
	// loop reusing the same Python name is free to keep it.
	mut bound := []string{}
	for name in for_target_names(node.target) {
		fresh := rename[name] or { name }
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
				body, flag := t.visit_loop_body(node.body, 2, has_else)
				buf << body
				buf << '\t}'
				t.emit_for_else(mut buf, node.orelse, flag)
				return buf.join('\n')
			}
			target = target_names.join(', ')

			// enumerate(seq) => for i, v in seq
			if node.iter is Call {
				call := node.iter as Call
				if call.func is Name {
					fname := (call.func as Name).id
					if fname == 'enumerate' && target_names.len == 2 && call.args.len > 0 {
						iter0 := t.visit_for_iter(call.args[0], saved_renames)
						buf << 'for ${target_names[0]}, ${target_names[1]} in ${iter0} {'
						body, flag := t.visit_loop_body(node.body, 1, has_else)
						buf << body
						buf << '}'
						t.emit_for_else(mut buf, node.orelse, flag)
						return buf.join('\n')
					}
					// zip(a, b) => for i, x in a { y := b[i]; ... }
					if fname == 'zip' && target_names.len == 2 && call.args.len >= 2 {
						left := t.visit_for_iter(call.args[0], saved_renames)
						right := t.visit_for_iter(call.args[1], saved_renames)
						idx := t.new_tmp('zipi')
						buf << 'for ${idx}, ${target_names[0]} in ${left} {'
						buf << '\t${target_names[1]} ${t.bind_op(target_names[1])} ${right}[${idx}]'
						body, flag := t.visit_loop_body(node.body, 1, has_else)
						buf << body
						buf << '}'
						t.emit_for_else(mut buf, node.orelse, flag)
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
				start := t.visit_for_iter(call.args[0], saved_renames)
				end := t.visit_for_iter(call.args[1], saved_renames)
				step := t.visit_for_iter(call.args[2], saved_renames)
				// For range with step, use traditional C-style for loop
				// Detect if step is -1 and use i-- instead of i += -1
				step_op := if step == '-1' { '${target}--' } else { '${target} += ${step}' }
				buf << 'for ${target} := ${start}; ${target} < ${end}; ${step_op} {'
				body, flag := t.visit_loop_body(node.body, 1, has_else)
				buf << body
				buf << '}'
				t.emit_for_else(mut buf, node.orelse, flag)
				return buf.join('\n')
			} else if fname == 'range' && call.args.len == 2 {
				start := t.visit_for_iter(call.args[0], saved_renames)
				end := t.visit_for_iter(call.args[1], saved_renames)
				for_expr = '[]int{len: ${paren_left(end, 4)} - ${paren_right(start, 4)}, init: index + ${paren_right(start, 4)}}'
			} else if fname == 'range' && call.args.len == 1 {
				end := t.visit_for_iter(call.args[0], saved_renames)
				for_expr = '[]int{len: ${end}, init: index}'
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
	body, flag := t.visit_loop_body(node.body, 1, has_else)
	buf << body
	buf << '}'
	t.emit_for_else(mut buf, node.orelse, flag)

	return buf.join('\n')
}

// visit_for_iter reads the iterable before the loop target rebinds its names.
fn (mut t VTranspiler) visit_for_iter(expr Expr, before map[string]string) string {
	inside := t.renamed_idents
	t.renamed_idents = before
	defer { t.renamed_idents = inside }
	return t.visit_expr(expr)
}

// LoopBreak is one loop whose body is being emitted. A loop with an `else`
// gets a flag the first time one of its own `break`s is emitted; a nested
// loop has its own entry, so its breaks never set the flag.
struct LoopBreak {
mut:
	has_else bool
	flag     string
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
		has_else: has_else
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
fn (mut t VTranspiler) emit_for_else(mut buf []string, orelse []Stmt, flag string) {
	if orelse.len == 0 {
		return
	}
	mut condition_renames := map[string]string{}
	for name in t.condition_walrus_order {
		if iter := t.renamed_idents[name] {
			if t.loop_idents[iter] {
				condition_renames[name] = iter
				t.renamed_idents.delete(name)
			}
		}
	}
	defer {
		for name, iter in condition_renames { t.renamed_idents[name] = iter }
	}
	if flag == '' {
		buf << 'if has_break != true {'
	} else {
		buf[0] = 'mut ${flag} := false'
		buf << 'if !${flag} {'
	}
	buf << t.visit_body_stmts(orelse, 1)
	buf << '}'
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
		// The channel has the element type its producer was declared with
		mut elem_type := t.infer_iter_elem_type(node.iter)
		if iter_call.func is Name {
			elem_type = t.generator_yield_types[(iter_call.func as Name).id] or { elem_type }
		}
		ch_type := if elem_type.len > 0 { elem_type } else { 'Any' }
		if ch_type == 'Any' {
			t.generated_code_has_any_type = true
		}
		buf << '${ch} := chan ${ch_type}{}'
		mut all_args := producer_args.clone()
		all_args << ch
		buf << 'go ${producer}(${all_args.join(', ')})'
		buf << 'for ${target} in ${ch} {'
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
		t.add_using('pyrt')
		return if t.fn_returns_result {
			'return py2v_raised_${node.guard}'
		} else {
			'pyrt.fail(py2v_raised_${node.guard})'
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
	t.add_using('pyrt')
	mut buf := []string{}
	buf << 'mut py2v_err_${n} := ?IError(none)'
	buf << 'py2v_try_${n}: for {'
	for stmt in node.body {
		buf << t.indent_code(t.visit_stmt(stmt), 1)
	}
	mut leaves := false
	if node.body.len > 0 {
		last := node.body.last()
		if last is Return {
			leaves = true
		} else if last is Raise {
			// a guarded `raise` has left the loop already
			leaves = last.mode == 'guard' && last.guard == n
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
		classes := handler.classes.map("'${it}'").join(', ')
		head := if name != '' {
			'if ${escape_local_decl(name)} := pyrt.caught(py2v_raised_${n}, ${classes}) '
		} else {
			'if pyrt.caught(py2v_raised_${n}, ${classes}) != none '
		}
		chain << '${head}{\n${body.join('\n')}\n}'
	}
	if !takes_all {
		escape := if t.fn_returns_result {
			'return py2v_raised_${n}'
		} else {
			'pyrt.fail(py2v_raised_${n})'
		}
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
		buf << '\tpyrt.unreachable()'
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
				mut value_types := []string{}
				if node.right is Tuple {
					tup := node.right as Tuple
					for elt in tup.elts {
						values << t.visit_expr(elt)
						value_types << t.infer_expr_type(elt)
					}
				} else {
					values << right
					value_types << t.infer_expr_type(node.right)
				}
				return convert_percent_format(fmt_str, values, value_types)
			}
		}
		return t.modulo_expression(*node.left, *node.right, left, right)
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
			return 'math.floor(${paren_left(left, 5)} / ${paren_right(right, 5)})'
		}
		return 'math.divide_floored(${left}, ${right}).quot'
	}

	// Handle string/list repetition
	if node.op is Mult {
		left_ann := get_expr_annotation(node.left)
		right_ann := get_expr_annotation(node.right)
		if right_ann == 'int' && (left_ann == 'string' || left_ann.starts_with('[]')) {
			return '${as_receiver(left)}.repeat(${right})'
		}
		// Also check by inferring types when v_annotation is not set
		left_type := t.infer_expr_type(node.left)
		if left_type == 'string' {
			return '${as_receiver(left)}.repeat(${right})'
		}
		// Check if left is a List literal - list repetition
		if node.left is List {
			return '${as_receiver(left)}.repeat(${right})'
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
		// A list display beside a list of known type has that type
		if !la.starts_with('[]') && node.left is List && ra.starts_with('[]') {
			la = ra
		}
		if !ra.starts_with('[]') && node.right is List && la.starts_with('[]') {
			ra = la
		}
		if la.starts_with('[]') && ra.starts_with('[]') {
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
	return '${paren_left(left, prec)} ${op} ${paren_right(right, prec)}'
}

// visit_unaryop emits V code for a unary operation (UnaryOp).
pub fn (mut t VTranspiler) visit_unaryop(node UnaryOp) string {
	op := op_to_symbol(get_unary_op_type(node.op))
	operand := t.visit_expr(node.operand)
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
			return '0 ${op} ${cmp_operand(right)}'
		}
	}

	return '${cmp_operand(left)} ${op} ${cmp_operand(right)}'
}

// visit_compare_chain emits `a < b <= c` as `a < b && b <= c`: one comparison for each
// operator, joined with `&&`, which stops at the first false one as Python does. A middle
// operand is written twice, so it is evaluated twice when it is not a plain value;
// bind_chain_middle binds it to a temporary first where the statement allows it.
fn (mut t VTranspiler) visit_compare_chain(node Compare) string {
	mut parts := []string{cap: node.ops.len}
	for i, op in node.ops {
		left := if i == 0 { *node.left } else { node.comparators[i - 1] }
		parts << t.visit_compare(Compare{
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

// Collect bindings and calls before emission, keeping definition-time expressions at module scope.
fn count_call_bindings[T](node T, mut names map[string]int, mut calls []BindingCall, in_function bool) {
	$if T is Call {
		calls << BindingCall{node, in_function}
	}
	$if T is Name {
		if node.ctx !is Load { names[node.id]++ }
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
		if value := node { count_call_bindings(value, mut names, mut calls, in_function) }
	} $else $if T is $pointer {
		count_call_bindings(*node, mut names, mut calls, in_function)
	} $else $if T is $array {
		for value in node { count_call_bindings(value, mut names, mut calls, in_function) }
	} $else $if T is $sumtype {
		$for variant in T.variants {
			if node is variant { count_call_bindings(node, mut names, mut calls, in_function) }
		}
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
			count_call_bindings(node.$(field.name), mut names, mut calls, body)
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

fn (t &VTranspiler) bind_module_call(node Call) ?Call {
	if node.func !is Name { return none }
	if t.call_before_def[node.loc.str()] { return none }
	name := (node.func as Name).id
	sig := t.call_signatures[name] or { return none }
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
			if !call_literal_default(expr) { return none }
			bound << expr
		}
	}
	return Call{ ...node, args: bound, keywords: []Keyword{} }
}

// guarded_call turns the text of a call that ends the program on an error into one that
// hands the error to the handlers of `try` number `n` and leaves the try body.
fn guarded_call(code string, n int) string {
	leave := ' or {\n\tpy2v_err_${n} = err\n\tbreak py2v_try_${n}\n}'
	passed := propagated_call(code)
	if passed.ends_with('!') && passed != code {
		return passed[..passed.len - 1] + leave
	}
	return code
}

// propagated_call turns the text of a call that ends the program on an error into one
// that passes the error on: `f(x) or { pyrt.fail(err) }` becomes `f(x)!`, and a call of a
// function of this file `g(x)` becomes `g_py(x)!` (the frontend marks only calls of
// functions it made fallible). Any other text is returned as it is.
fn propagated_call(code string) string {
	suffix := ' or { pyrt.fail(err) }'
	if code.starts_with('(') && code.ends_with(suffix + ')') {
		return code[1..code.len - suffix.len - 1] + '!'
	}
	if code.ends_with(suffix) {
		return code[..code.len - suffix.len] + '!'
	}
	open := code.index('(') or { return code }
	name := code[..open]
	if name.len == 0 || !code.ends_with(')') || name.contains_any(' .\n{}[]=') {
		return code
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

// visit_call binds eligible module functions before rendering their arguments.
pub fn (mut t VTranspiler) visit_call(original Call) string {
	if original.guard > 0 {
		// a call that can fail, in the body of a `try` whose handlers take the error
		code, optional := without_opt(t.visit_call(Call{
			...original
			guard: 0
		}))
		guarded := guarded_call(code, original.guard)
		return if optional { '(${guarded}).opt()' } else { guarded }
	}
	if original.propagate {
		// a call that can fail, in straight-line code of a function returning a result
		code, optional := without_opt(t.visit_call(Call{
			...original
			propagate: false
		}))
		passed := propagated_call(code)
		return if optional { passed + '.opt()' } else { passed }
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
	if completed := t.complete_imported_call(original) {
		return t.visit_call(completed)
	}
	node := t.bind_module_call(original) or { original }
	mut fname := t.visit_expr(node.func)

	// Check if this function has mut parameters
	mut_indices := t.mut_param_indices[fname] or { []int{} }

	mut vargs := []string{}
	mut list_arg_slots := []int{}
	declared_params := t.func_param_types[fname] or { []string{} }
	for i, arg in node.args {
		mut arg_str := t.typed_literal_arg(arg)
		// A dict literal for a parameter declared with a value type has that type
		if arg is Dict && (arg as Dict).keys.len > 0 && i < declared_params.len
			&& declared_params[i].starts_with('map[') && !declared_params[i].ends_with(']Any') {
			arg_str = declared_params[i] + t.visit_expr(arg)
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
		t.generated_code_has_any_type = true
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

	// Python's integer math functions. V's `math.factorial` is the float one and
	// it has no `isqrt`; the integer forms return i64, cast back to py2v's int.
	if vargs.len == 1 && fname in ['math.isqrt', 'math.factorial'] {
		t.add_using('math')
		v_fn := if fname == 'math.isqrt' { 'sqrti' } else { 'factoriali' }
		return 'int(math.${v_fn}(${vargs[0]}))'
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
			return '${obj} << ${vargs[0]}'
		}

		// An explicit `BuiltinError.__init__(self, ...)` reaches a class V has no
		// counterpart for. Portage does exactly this to mix a builtin exception
		// into its own hierarchy, as in `class E(KeyError, Base)`.
		if method == '__init__' && attr_node.value is Name {
			recv := (attr_node.value as Name).id
			if recv in t.known_classes {
				// V reaches an embedded base through the receiver, so an explicit
				// `Base.__init__(self, x)` becomes `self.Base.init(x)`: the
				// receiver is implicit in V and must not be forwarded.
				mut base_args := vargs
				if base_args.len > 0 && base_args[0] == 'self' {
					base_args = base_args[1..]
				}
				if base_args.len > 0 {
					return 'self.${emitted_class_name(recv)}.init(${base_args.join(', ')})'
				}
				return 'self.${emitted_class_name(recv)}.init()'
			}
			if !t.is_known_module_receiver(recv) {
				t.note_unmapped_call(fname)
				t.generated_code_has_any_type = true
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
						if less, has_key := sort_less(mut t, node, elem) {
							if has_key {
								t.add_using('arrays')
								return 'arrays.stable_sort(mut ${obj}, fn (lhs ${elem}, rhs ${elem}) bool { return ${less} })'
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
	if is_ctor {
		// Keep the module qualifier: `Box{}` would refer to nothing when the
		// class lives in another V module.
		mut emitted_ctor := if ctor_lookup == fname {
			emitted_class_name(fname)
		} else {
			fname
		}
		if ctor_lookup in t.ref_classes {
			emitted_ctor = '&${emitted_ctor}'
		}
		return t.ctor_struct_literal(emitted_ctor, fname, node, vargs)
	}
	if node.func is Attribute {
		callee := node.func as Attribute
		method := escape_leading_underscore(callee.attr)
		if method.len > 0 && method[0].is_capital()
			&& (vargs.len != 1 || node.keywords.len > 0) {
			// V reads module.Type(a, b) as a cast. A constructor must have a
			// resolved lowering; retain every operand in an explicit refusal.
			mut operands := ["'${escape_string(fname)}'"]
			if !(callee.value is Name && t.is_known_module_receiver(callee.value.id)) {
				operands << t.visit_expr(callee.value)
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
		t.generated_code_has_any_type = true
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
fn has_class_annotation(annotation Expr) bool {
	return match annotation {
		Name {
			annotation.api.starts_with('__project_type__.') || annotation.api in runtime_class_types || annotation.api in runtime_api
		}
		Attribute {
			annotation.api.starts_with('__project_type__.') || annotation.api in runtime_class_types || annotation.api in runtime_api
		}
		Subscript {
			has_class_annotation(*annotation.value) || has_class_annotation(*annotation.slice)
		}
		Tuple { annotation.elts.any(has_class_annotation(it)) }
		BinOp { has_class_annotation(*annotation.left) || has_class_annotation(*annotation.right) }
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
	if node.bound_append == 'list' {
		return '${t.runtime_helper('append_method')}(mut ${t.visit_expr(node.value)})'
	}
	if node.bound_append != '' {
		return 'py2v_unsupported_bound_append_${node.bound_append}(${t.visit_expr(node.value)})'
	}
	if node.api != '' {
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
	//
	// Everything else has to shed a leading underscore. V reads `x._foo` as the
	// string literal `x.'foo'`, because `_` is a string prefix character, and a
	// leading underscore is not a legal field name either. Python reaches these
	// constantly for private attributes, so the rewrite matches the one the
	// declaration sites apply.
	attr = python_dunder_method_names[attr] or { escape_leading_underscore(attr) }
	attr_path := '${value}.${attr}'

	// Try attribute dispatch
	result, handled := dispatch_attr(mut t, attr_path)
	if handled {
		return result
	}

	return '${value}.${attr}'
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
	if node.elts.len == 0 {
		annotation := node.v_annotation or { '' }
		if annotation.starts_with('list[') {
			typ := map_type(annotation)
			if typ.contains('Any') {
				t.generated_code_has_any_type = true
			}
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
	if node.keys.len == 0 {
		annotation := node.v_annotation or { '' }
		if annotation.starts_with('dict[') {
			typ := map_type(annotation)
			if typ.contains('Any') {
				t.generated_code_has_any_type = true
			}
			return '${typ}{}'
		}
		// V has no untyped empty map literal; fall back to a string-keyed map,
		// which is what Python code almost always means for `{}`.
		t.generated_code_has_any_type = true
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
			k := t.visit_expr(key)
			v := t.visit_expr(node.values[i])
			pairs << '\t${k}: ${v}'
		}
	}
	return '{\n${pairs.join(',\n')},\n}'
}

// typed_literal_arg renders one call argument, giving a collection literal the
// explicit element type V cannot infer in argument position.
pub fn (mut t VTranspiler) typed_literal_arg(arg Expr) string {
	if arg is Dict && (arg as Dict).keys.len > 0 {
		t.generated_code_has_any_type = true
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
	return 'if ${test} { ${body} } else { ${orelse} }'
}

// ifexp_value retains the float type of integral literals in a value choice.
// json2 can decode 0.0 as an integer; an int first branch would truncate 2.5.
fn (mut t VTranspiler) ifexp_value(expr Expr) string {
	if expr is Constant && (expr.v_annotation or { '' }) == 'float' {
		code := t.visit_constant(expr)
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
	return '${t.runtime_helper('distinct')}(${t.visit_generator_exp_impl(node.elt, node.generators)})'
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
	// A walrus in the element needs a statement too: `.map(...)` takes one
	// expression, and V has no assignment expression.
	if contains_condition_walrus(elt) {
		return t.visit_generator_exp_impl_walrus(elt, generators)
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
					result = '[]int{len: ${paren_left(end, 4)} - ${paren_right(start, 4)}, init: index + ${paren_right(start, 4)}}'
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
		if t.is_map_expr(iter) {
			// iterating a dict visits its keys
			result = '${as_receiver(result)}.keys()'
		}
	}

	// Apply filters - need to use 'it' for the element reference
	for if_clause in generators[0].ifs {
		mut filter_expr := t.visit_expr(if_clause)
		// Replace target variable with 'it' for filter lambda
		filter_expr = if is_comp_identifier(target) {
			replace_comp_identifier(filter_expr, target, 'it')
		} else {
			filter_expr.replace(target, 'it')
		}
		result = '${as_receiver(result)}.filter(${filter_expr})'
	}

	// Apply map - need to use 'it' for the element reference
	mut map_expr := t.visit_expr(elt)
	// Replace target variable with 'it' for map lambda
	map_expr = if is_comp_identifier(target) {
		replace_comp_identifier(map_expr, target, 'it')
	} else {
		map_expr.replace(target, 'it')
	}
	result = '${as_receiver(result)}.map(${map_expr})'

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
	expr := t.visit_expr(node.value)
	return "'\${${expr}}'"
}

// fmtval_segment returns the inner interpolation text for one FormattedValue
// node, to be embedded inside a surrounding single-quoted V string.
fn (mut t VTranspiler) fmtval_segment(node FormattedValue) string {
	expr := t.visit_expr(node.value)
	return '\${${expr}}'
}

// fstring_spec_args parses a constant f-string format spec with Python's format
// mini-language, [[fill]align][sign][0][width][grouping][.precision][type], and
// returns the arguments py2v_format takes after the value. It returns none for a
// form py2v_format does not cover, which keeps the plain `${expr}` emission.
fn fstring_spec_args(node FormattedValue) ?string {
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
	typ := if i < r.len { r[i].str() } else { '' }
	if i + typ.runes().len != r.len || typ !in ['', 'd', 's', 'e', 'E', 'f', 'F', 'g', 'G', '%'] {
		return none
	}
	// Python puts grouping separators into zero padding; that is not covered.
	if group != '' && (zero || align == '=') {
		return none
	}
	return "'${fill}', '${align}', '${sign}', ${zero}, ${width}, '${group}', ${prec}, '${typ}'"
}

// py2v_format_helper is emitted once per V module whose f-strings call py2v_format.
const py2v_format_helper = r"// py2v_format formats x as Python's format(x, spec) does, from the spec fields
// py2v parsed: fill, align ('' for the default), sign, the 0 flag, width,
// grouping separator, precision (-1 when absent) and type. Floats go through
// C's snprintf, which rounds the exact binary value as CPython does. A value
// or spec not covered here prints as plain interpolation would.
fn py2v_format[T](x T, fill string, align string, sign string, zero bool, width int, group string, prec int, typ string) string {
	mut body := ''
	mut numeric := true
	$if T is rune {
		numeric = false
		body = if prec == 0 { '' } else { x.str() }
	} $else $if T is $int {
		if typ in ['e', 'E', 'f', 'F', 'g', 'G', '%'] {
			body = py2v_format_c(f64(x), sign, prec, typ)
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
		body = py2v_format_c(f64(x), sign, prec, typ)
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

// py2v_format_c formats x for Python's types e, E, f, F, g, G and %.
fn py2v_format_c(x f64, sign string, prec int, typ string) string {
	if x != x {
		// C libraries differ on the sign of a NaN; Python prints none unless the spec asks.
		nan := if typ in ['E', 'F', 'G'] { 'NAN' } else { 'nan' }
		return (if sign == '-' { '' } else { sign }) + nan + if typ == '%' { '%' } else { '' }
	}
	p := if prec >= 0 { prec } else { 6 }
	cfmt := if typ == '%' { '%${sign}.${p}f%%' } else { '%${sign}.${p}${typ}' }
	v := if typ == '%' { x * 100.0 } else { x }
	n := unsafe { C.snprintf(nil, 0, &char(cfmt.str), v) }
	mut buf := []u8{len: n + 1}
	unsafe { C.snprintf(&char(buf.data), uint(n + 1), &char(cfmt.str), v) }
	return buf[..n].bytestr()
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
				if t.comp_depth == 0 {
					if args := fstring_spec_args(val) {
						t.uses_py2v_format = true
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
			t.generated_code_has_any_type = true
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
			// A parameter that holds a class (`unit: type = int`) has no V type.
			if name == 'type' {
				t.generated_code_has_any_type = true
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
				t.generated_code_has_any_type = true
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
				t.generated_code_has_any_type = true
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
			if raw_index == '' { t.generated_code_has_any_type = true }

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
				if unique.len > 1 {
					t.generated_code_has_any_type = true
				}
				t.pending_type_notes << '// NOTE: Literal[${index}] — allowed values are ${index}'
				return base_type
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
							t.generated_code_has_any_type = true
						}
						if v == '' {
							v = 'Any'
							t.generated_code_has_any_type = true
						}
						return 'map[${k}]${v}'
					}
				}
				t.generated_code_has_any_type = true
				return 'map[${index}]Any'
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
				t.generated_code_has_any_type = true
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
					t.generated_code_has_any_type = true
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
	for stmt in stmts {
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
