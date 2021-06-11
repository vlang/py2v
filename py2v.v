import io.util
import os

import json2v

fn get_python_executable() ?string {
	for executable_name in ['python3', 'python'] {
		if !os.exists_in_system_path(executable_name) {
			continue
		}

		if os.execute('$executable_name -c \'if __import__("sys").version_info < (3, 6): exit(1)\'').exit_code != 0 {
			continue
		}

		return executable_name
	}
	return error('Cannot find valid python executable.')
}

fn main() {
	if os.args.len != 3 {
		eprintln('usage: ${os.args[0]} <Python source> <V destination>')
		exit(2)
	}

	if !os.exists(os.args[1]) {
		eprintln('error: Cannot find python source.')
		exit(1)
	}

	python := get_python_executable() or {
		eprintln('error: ${err.msg}')
		exit(1)
	}

	mut ast_file, file_path := util.temp_file(pattern: 'py2v_*.json') or {
		eprintln('error: ${err.msg}')
		exit(1)
	}
	ast_file.close()

	defer { 
		os.rm(file_path) or {
			eprintln('error: Failed to remove temp file $file_path: ${err.msg}')
			exit(1)
		}
	}

	if os.execute('$python ast2json.py ${os.args[1]} $file_path').exit_code != 0 {
		eprintln('error: Failed to convert Python ast to json.')
		exit(1)
	}

	ast_source := os.read_file(file_path) or {
		eprintln('error: Cannot read ast source: ${err.msg}')
		exit(1)
	}
	output := json2v.transpile(ast_source) or {
		eprintln('error: Failed to transpile python source: ${err.msg}')
		exit(1)
	}
	os.write_file(os.args[2], output) or {
		eprintln('error: Cannot write V output: ${err.msg}')
		exit(1)
	}
}