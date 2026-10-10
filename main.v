module main

import os

fn main() {
	args := os.args[1..]

	if args.len == 0 {
		eprintln('Usage: py2v <input.py> [-o output.v]')
		eprintln('')
		eprintln('Transpiles Python source code to V.')
		eprintln('')
		eprintln('Options:')
		eprintln('  -o <file>       Write output to file instead of stdout')
		eprintln('  --package <dir> Translate a Python package as a multi-module project')
		eprintln('  --module-name <n> V module name for single-file output (default: main)')
		eprintln('  -h, --help      Show this help message')
		exit(1)
	}

	// Parse arguments
	mut input_file := ''
	mut output_file := ''
	mut module_name := 'main'
	mut package_root := '' // Python package dir to translate as one project
	mut i := 0

	for i < args.len {
		arg := args[i]
		if arg == '-o' && i + 1 < args.len {
			output_file = args[i + 1]
			i += 2
		} else if arg == '--package' && i + 1 < args.len {
			package_root = args[i + 1]
			i += 2
		} else if arg == '--module-name' && i + 1 < args.len {
			module_name = sanitize_module_name(args[i + 1])
			i += 2
		} else if arg == '-h' || arg == '--help' {
			eprintln('Usage: py2v <input.py> [-o output.v]')
			eprintln('')
			eprintln('Transpiles Python source code to V.')
			eprintln('')
			eprintln('Options:')
			eprintln('  -o <file>       Write output to file instead of stdout')
			eprintln('  --package <dir> Translate a Python package as a multi-module project')
			eprintln('  --module-name <n> V module name for single-file output (default: main)')
			eprintln('  -h, --help      Show this help message')
			exit(0)
		} else if !arg.starts_with('-') {
			input_file = arg
			i++
		} else {
			eprintln('Unknown option: ${arg}')
			exit(1)
		}
	}

	if input_file == '' && package_root == '' {
		eprintln('Error: No input file or --package specified')
		exit(1)
	}
	if output_file != '' && package_root == '' {
		module_name = module_name_from_output_path(output_file)
	}

	// Get the directory where this executable is located
	exe_path := os.executable()
	exe_dir := os.dir(exe_path)

	// Try to find ast_dump.py relative to executable, then fall back to common locations
	mut ast_dump_paths := []string{}
	ast_dump_paths << os.join_path(exe_dir, 'frontend', 'ast_dump.py')
	ast_dump_paths << os.join_path(exe_dir, '..', 'py2v', 'frontend', 'ast_dump.py')
	ast_dump_paths << os.join_path(os.getwd(), 'py2v', 'frontend', 'ast_dump.py')

	mut ast_dump_path := ''
	for path in ast_dump_paths {
		if os.exists(path) {
			ast_dump_path = path
			break
		}
	}

	if ast_dump_path == '' {
		eprintln('Error: Could not find ast_dump.py')
		eprintln('Looked in:')
		for path in ast_dump_paths {
			eprintln('  ${path}')
		}
		exit(1)
	}

	// Multi-module project mode: translate a whole Python package, wiring
	// cross-module imports to V modules.
	python_cmd := $if windows { 'python' } $else { 'python3' }
	if package_root != '' {
		ast_dump_dir := os.dir(ast_dump_path)
		out_root := if output_file != '' { output_file } else { 'out' }
		translate_package(python_cmd, os.join_path(ast_dump_dir, 'ast_dump.py'),
			package_root, out_root, module_name) or {
			eprintln('error: ${err}')
			exit(1)
		}
		return
	}

	// Run Python frontend to get JSON AST
	result := os.exec_opt([python_cmd, ast_dump_path, input_file]) or { exit(1) }
	if result.exit_code != 0 {
		eprintln('Error running Python frontend:')
		eprintln(result.output)
		exit(1)
	}

	json_ast := result.output

	// Parse JSON AST
	ast := parse_ast(json_ast) or {
		eprintln('Error parsing AST: ${err}')
		exit(1)
	}

	// Transpile to V
	mut transpiler := new_transpiler()
	transpiler.module_name = module_name
	v_code := transpiler.visit_module(ast)

	// Format with vfmt
	formatted_code := format_v_code(v_code)

	// Output
	if output_file != '' {
		os.write_file(output_file, formatted_code) or {
			eprintln('Error writing output file: ${err}')
			exit(1)
		}
		eprintln('Wrote ${output_file}')
	} else {
		print(formatted_code)
	}
}

fn module_name_from_output_path(output_file string) string {
	dir_name := os.base(os.dir(output_file))
	if dir_name == '' || dir_name == '.' || dir_name == '/' || dir_name == '\\' {
		return 'main'
	}
	return sanitize_module_name(dir_name)
}

fn sanitize_module_name(raw string) string {
	if raw == '' {
		return 'main'
	}
	mut out := []u8{}
	for i, ch in raw {
		is_alpha := (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`)
		is_digit := ch >= `0` && ch <= `9`
		is_valid_start := is_alpha || ch == `_`
		is_valid_body := is_alpha || is_digit || ch == `_`
		if i == 0 {
			if is_valid_start {
				out << ch
			} else if is_digit {
				out << `m`
				out << `_`
				out << ch
			} else {
				out << `m`
				out << `_`
			}
			continue
		}
		if is_valid_body {
			out << ch
		} else {
			out << `_`
		}
	}
	if out.len == 0 {
		return 'main'
	}
	return out.bytestr()
}

fn format_v_code(code string) string {
	// Write to temp file, format in-place with vfmt -w, then read back
	tmp_file := os.temp_dir() + '/py2v_tmp_${os.getpid()}.v'
	os.write_file(tmp_file, code) or { return code }
	defer {
		os.rm(tmp_file) or {}
	}

	result := os.exec_opt(['v', 'fmt', '-w', tmp_file]) or { return code }
	if result.exit_code == 0 {
		formatted := os.read_file(tmp_file) or { return code }
		return formatted
	}
	// If vfmt fails, return original code
	return code
}

// run_frontend invokes the Python frontend for one source file and returns the
// parsed module.
fn run_frontend(python_cmd string, ast_dump string, src string) !Module {
	res := os.exec_opt([python_cmd, ast_dump, src]) or {
		return error('could not run frontend: ${err}')
	}
	if res.exit_code != 0 {
		return error('frontend failed for ${src}:\n${res.output}')
	}
	return parse_ast(res.output)!
}

// collect_module_symbols returns the top-level names a module defines. These are
// the names other modules may import from it.
fn collect_module_symbols(mod Module) []string {
	mut names := []string{}
	for stmt in mod.body {
		match stmt {
			FunctionDef {
				names << (stmt as FunctionDef).name
			}
			AsyncFunctionDef {
				names << (stmt as AsyncFunctionDef).name
			}
			ClassDef {
				names << (stmt as ClassDef).name
			}
			Assign {
				// Only simple `name = ...` binds a module-level symbol.
				targets := (stmt as Assign).targets
				if targets.len == 1 && targets[0] is Name {
					names << (targets[0] as Name).id
				}
			}
			AnnAssign {
				if (stmt as AnnAssign).target is Name {
					names << ((stmt as AnnAssign).target as Name).id
				}
			}
			else {}
		}
	}
	return names
}

// find_python_files recursively lists .py files under root, skipping caches.
fn find_python_files(root string) ![]string {
	mut out := []string{}
	mut queue := [root]
	for queue.len > 0 {
		dir := queue.pop()
		entries := os.ls(dir) or { continue }
		for base in entries {
			// os.ls yields basenames, so rebuild the full path.
			entry := os.join_path(dir, base)
			name := os.base(entry)
			if os.is_dir(entry) {
				// Skip caches, hidden dirs and tests for now.
				if name.starts_with('.') || name == '__pycache__' || name == 'tests' {
					continue
				}
				queue << entry
				continue
			}
			if name.ends_with('.py') {
				out << entry
			}
		}
	}
	out.sort()
	return out
}

// translate_package transpiles a Python package tree into a multi-module V
// project rooted at out_root.
fn translate_package(python_cmd string, ast_dump string, package_dir string, out_root string, root_module string) ! {
	abs_root := os.abs_path(package_dir)
	if !os.exists(abs_root) {
		return error('package directory not found: ${abs_root}')
	}
	files := find_python_files(abs_root)!

	// The root package name is the directory name, matching how Python would
	// import it if its parent were on sys.path.
	root_dotted := sanitize_module_name(os.base(abs_root))

	// Pass 1: parse every module and record its symbols, so that cross-module
	// references can be resolved during pass 2.
	mut registry := new_module_registry()
	registry.root_dotted = root_dotted
	registry.output_root = out_root
	mut parsed := map[string]Module{}
	for file in files {
		rel := rel_path(abs_root, file)
		raw := py_dotted_from_path(rel)
		// py_dotted_from_path drops the `__init__` marker; re-append it so the
		// package file can be routed to `mod.v`.
		mut dotted := root_dotted + '.' + raw
		is_init := rel.replace('\\', '/').ends_with('__init__.py')
		if is_init {
			dotted += '.__init__'
		}
		if is_init && rel.replace('\\', '/') == '__init__.py' {
			// The root package itself has no V module of its own.
			continue
		}
		mod := run_frontend(python_cmd, ast_dump, file)!
		parsed[dotted] = mod
		v_mod := v_module_from_py_path(dotted, root_dotted)
		// `a/b/__init__.py` is the package `a.b`; it emits to `a/b/mod.v` and
		// shares the V module of directory `a/b`. Register it under both names
		// so `from a.b import x` resolves.
		if is_init {
			if dotted.len >= root_dotted.len + 10 {
				pkg_dotted := dotted[..dotted.len - 10]
				registry.add_module(PyModuleInfo{
					dotted:    pkg_dotted
					v_module:  v_mod
					v_relpath: v_relpath_from_py_path(dotted)
					symbols:   collect_module_symbols(mod)
				})
				for cls in collect_classes(mod) {
					registry.class_fields_by_path['${pkg_dotted}.${cls.name}'] = cls.fields
				}
				for m in collect_mut_methods(mod) {
					registry.mut_methods['${pkg_dotted}.${m}'] = true
				}
			}
		}
		registry.add_module(PyModuleInfo{
			dotted:    dotted
			v_module:  v_mod
			v_relpath: v_relpath_from_py_path(dotted)
			symbols:   collect_module_symbols(mod)
		})
		for cls in collect_classes(mod) {
			registry.class_fields_by_path['${dotted}.${cls.name}'] = cls.fields
		}
		// Record which imported methods need a `mut` receiver so call sites on
		// local variables of that class can declare the variable `mut`.
		for m in collect_mut_methods(mod) {
			registry.mut_methods[m] = true
		}
	}

	dupes := registry.collisions()
	if dupes.len > 0 {
		mut keys := dupes.keys()
		keys.sort()
		for key in keys {
			owners := dupes[key]!
			eprintln('warning: symbol collision ${key} defined in ${owners.join(', ')}')
		}
	}

	// Pass 2: emit each module with the registry in place.
	mut count := 0
	mut dotted_keys := parsed.keys()
	dotted_keys.sort()
	for key in dotted_keys {
		info := registry.lookup(key)
		mut t := new_transpiler()
		t.emit_pub = true
		t.registry = registry
		t.current_dotted = key
		t.module_name = info.v_module
		code := t.visit_module(parsed[key]!)
		formatted := format_v_code(code)
		out_path := os.join_path(out_root, info.v_relpath)
		os.mkdir_all(os.dir(out_path)) or { return err }
		os.write_file(out_path, formatted) or { return err }
		count++
	}
	eprintln('Transpiled ${count} modules into ${out_root}')
}

// rel_path returns `path` expressed relative to `base`, using forward slashes.
fn rel_path(base string, path string) string {
	mut b := base.replace('\\', '/')
	mut p := path.replace('\\', '/')
	if !b.ends_with('/') {
		b += '/'
	}
	if p.starts_with(b) {
		return p[b.len..]
	}
	return os.base(p)
}

// PyClassSummary is a class name with its field order, used for cross-module
// struct literal generation.
struct PyClassSummary {
	name   string
	fields []string
}

// collect_classes returns the classes a module defines together with their
// field order, so other modules can build struct literals for them.
fn collect_classes(mod Module) []PyClassSummary {
	mut out := []PyClassSummary{}
	for stmt in mod.body {
		if stmt !is ClassDef {
			continue
		}
		cd := stmt as ClassDef
		mut fields := []string{}
		for field in cd.declarations.keys() {
			fields << field
		}
		fields.sort()
		out << PyClassSummary{
			name:   cd.name
			fields: fields
		}
	}
	return out
}

// collect_mut_methods returns `Class.method` pairs whose V receiver is `mut`.
fn collect_mut_methods(mod Module) []string {
	mut out := []string{}
	for stmt in mod.body {
		if stmt !is ClassDef {
			continue
		}
		cd := stmt as ClassDef
		for body in cd.body {
			if body !is FunctionDef {
				continue
			}
			fd := body as FunctionDef
			is_binop := fd.dunder_op in ['+', '-', '*', '/', '%', '==', '!=', '<', '<=', '>=']
			if !is_binop && ('self' in fd.mutable_vars || fd.name == '__init__') {
				mut v_name := fd.dunder_op
				if v_name == '' {
					v_name = python_dunder_method_names[fd.name] or { fd.name }
				}
				out << '${cd.name}.${v_name}'
			}
		}
	}
	return out
}
