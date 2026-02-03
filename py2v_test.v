module main

import os

fn test_transpiler() {
	script_dir := os.dir(@FILE)
	cases_dir := os.join_path(script_dir, 'tests', 'cases')
	expected_dir := os.join_path(script_dir, 'tests', 'expected')
	py2v_path := os.join_path(script_dir, 'py2v')

	if !os.exists(py2v_path) {
		assert false, 'py2v executable not found - run: v . -o py2v'
		return
	}

	cases := os.glob('${cases_dir}/*.py') or {
		assert false, 'Could not find test cases'
		return
	}

	mut failed := []string{}

	for case_file in cases {
		test_name := os.file_name(case_file).replace('.py', '')
		expected_file := os.join_path(expected_dir, '${test_name}.v')

		if !os.exists(expected_file) {
			continue
		}

		result := os.execute('${py2v_path} "${case_file}"')
		if result.exit_code != 0 {
			failed << '${test_name}: transpilation failed'
			continue
		}

		generated := result.output.trim_space()
		expected := os.read_file(expected_file) or {
			failed << '${test_name}: could not read expected file'
			continue
		}

		if generated != expected.trim_space() {
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
