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
		eprintln('  -o <file>    Write output to file instead of stdout')
		eprintln('  -h, --help       Show this help message')
		exit(1)
	}

	// Parse arguments
	mut input_file := ''
	mut output_file := ''
	mut module_name := 'main'
	mut i := 0

	for i < args.len {
		arg := args[i]
		if arg == '-o' && i + 1 < args.len {
			output_file = args[i + 1]
			i += 2
		} else if arg == '-h' || arg == '--help' {
			eprintln('Usage: py2v <input.py> [-o output.v]')
			eprintln('')
			eprintln('Transpiles Python source code to V.')
			eprintln('')
			eprintln('Options:')
			eprintln('  -o <file>    Write output to file instead of stdout')
			eprintln('  -h, --help       Show this help message')
			exit(0)
		} else if !arg.starts_with('-') {
			input_file = arg
			i++
		} else {
			eprintln('Unknown option: ${arg}')
			exit(1)
		}
	}

	if input_file == '' {
		eprintln('Error: No input file specified')
		exit(1)
	}
	if output_file != '' {
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

	// Run Python frontend to get JSON AST
	python_cmd := $if windows { 'python' } $else { 'python3' }
	result := os.execute('${python_cmd} "${ast_dump_path}" "${input_file}"')
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
	if raw.len == 0 {
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
	// Write to temp file, format with vfmt, read back
	tmp_file := os.temp_dir() + '/py2v_tmp_${os.getpid()}.v'
	os.write_file(tmp_file, code) or { return code }
	defer {
		os.rm(tmp_file) or {}
	}

	result := os.execute('v fmt "${tmp_file}"')
	if result.exit_code == 0 {
		formatted := os.read_file(tmp_file) or { return code }
		return formatted
	}
	// If vfmt fails, return original code
	return code
}
