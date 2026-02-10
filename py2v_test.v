module main

import os

fn test_transpiler() {
	script_dir := os.dir(@FILE)
	cases_dir := os.join_path(script_dir, 'tests', 'cases')
	expected_dir := os.join_path(script_dir, 'tests', 'expected')
	py2v_path := os.join_path(script_dir, $if windows { 'py2v.exe' } $else { 'py2v' })

	if !os.exists(py2v_path) {
		assert false, 'py2v executable not found - run: v . -o py2v'
		return
	}

	cases := os.glob('${cases_dir}/*.py') or {
		assert false, 'Could not find test cases'
		return
	}

	mut failed := []string{}

	for raw_case in cases {
		// os.glob on Windows may return just filenames, not full paths
		case_file := if os.is_abs_path(raw_case) { raw_case } else { os.join_path(cases_dir, raw_case) }
		test_name := os.file_name(case_file).replace('.py', '')
		expected_file := os.join_path(expected_dir, '${test_name}.v')

		if !os.exists(expected_file) {
			continue
		}

		result := os.execute('${py2v_path} "${case_file}"')
		if result.exit_code != 0 {
			err_msg := result.output.trim_space()
			if err_msg.len > 0 {
				failed << '${test_name}: ${err_msg}'
			} else {
				failed << '${test_name}: transpilation failed (exit code ${result.exit_code})'
			}
			continue
		}

		generated := result.output.trim_space().replace('\r\n', '\n')
		expected := (os.read_file(expected_file) or {
			failed << '${test_name}: could not read expected file'
			continue
		}).trim_space().replace('\r\n', '\n')

		if generated != expected {
			failed << '${test_name}: output mismatch'
		}
	}

	if failed.len > 0 {
		for f in failed {
			eprintln(f)
		}
		assert false, '${failed.len} tests failed'
	}
}
