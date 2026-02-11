module main

import os

fn find_repo_root(start string) !string {
	mut dir := os.real_path(start)
	for {
		if os.exists(os.join_path(dir, 'main.v')) && os.exists(os.join_path(dir, 'tests', 'cases')) {
			return dir
		}
		parent := os.dir(dir)
		if parent == dir || parent.len == 0 {
			break
		}
		dir = parent
	}
	return error('could not locate repo root from ${start}')
}

fn detect_repo_root() !string {
	cwd := os.getwd()
	if os.exists(os.join_path(cwd, 'main.v')) && os.exists(os.join_path(cwd, 'tests', 'cases')) {
		return cwd
	}
	return find_repo_root(os.dir(@FILE))
}

fn ensure_fresh_py2v(repo_dir string) !string {
	bin_name := $if windows { 'py2v_test_${os.getpid()}.exe' } $else { 'py2v_test_${os.getpid()}' }
	py2v_path := os.join_path(repo_dir, bin_name)
	prev_cwd := os.getwd()
	os.chdir(repo_dir) or { return error('failed to chdir to ${repo_dir}: ${err}') }
	defer {
		os.chdir(prev_cwd) or {}
	}

	build := os.execute('v . -o "${py2v_path}"')
	if build.exit_code != 0 {
		return error('failed to build py2v: ${build.output}')
	}
	return py2v_path
}

fn normalize_v_code(code string) string {
	mut normalized := code.replace('\r\n', '\n')
	tmp_file := os.join_path(os.temp_dir(), 'py2v_test_fmt_${os.getpid()}.v')
	os.write_file(tmp_file, normalized) or { return normalized.trim_space() }
	defer {
		os.rm(tmp_file) or {}
	}
	res := os.execute('v fmt -w "${tmp_file}"')
	if res.exit_code == 0 {
		normalized = os.read_file(tmp_file) or { normalized }
	}
	return normalized.replace('\r\n', '\n').trim_space()
}

fn test_transpiler() {
	repo_dir := detect_repo_root() or {
		assert false, err.msg()
		return
	}
	cases_dir := os.join_path(repo_dir, 'tests', 'cases')
	expected_dir := os.join_path(repo_dir, 'tests', 'expected')
	py2v_path := ensure_fresh_py2v(repo_dir) or {
		assert false, err.msg()
		return
	}

	cases := os.glob('${cases_dir}/*.py') or {
		assert false, 'Could not find test cases'
		return
	}

	mut failed := []string{}

	for raw_case in cases {
		// os.glob on Windows may return just filenames, not full paths
		case_file := if os.is_abs_path(raw_case) {
			raw_case
		} else {
			os.join_path(cases_dir, raw_case)
		}
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

		generated := normalize_v_code(result.output)
		expected := (os.read_file(expected_file) or {
			failed << '${test_name}: could not read expected file'
			continue
		})
		expected_norm := normalize_v_code(expected)

		if generated != expected_norm {
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

fn test_module_name_from_output_path() {
	repo_dir := detect_repo_root() or {
		assert false, err.msg()
		return
	}
	py2v_path := ensure_fresh_py2v(repo_dir) or {
		assert false, err.msg()
		return
	}
	case_file := os.join_path(repo_dir, 'tests', 'cases', 'hello_world.py')

	tmp_root := os.join_path(os.temp_dir(), 'py2v_mod_test_${os.getpid()}')
	os.mkdir_all(tmp_root) or {
		assert false, 'failed to create temp dir: ${err}'
		return
	}
	defer {
		os.rmdir_all(tmp_root) or {}
	}

	out_dir_alpha := os.join_path(tmp_root, 'foo-bar')
	os.mkdir_all(out_dir_alpha) or {
		assert false, 'failed to create temp output dir: ${err}'
		return
	}
	out_file_alpha := os.join_path(out_dir_alpha, 'out.v')
	res_alpha := os.execute('${py2v_path} "${case_file}" -o "${out_file_alpha}"')
	assert res_alpha.exit_code == 0, 'transpilation failed: ${res_alpha.output}'
	alpha_text := os.read_file(out_file_alpha) or {
		assert false, 'failed to read output file: ${err}'
		return
	}
	assert alpha_text.contains('\nmodule foo_bar\n'), 'expected module foo_bar in generated output'

	out_dir_digit := os.join_path(tmp_root, '123abc')
	os.mkdir_all(out_dir_digit) or {
		assert false, 'failed to create temp output dir: ${err}'
		return
	}
	out_file_digit := os.join_path(out_dir_digit, 'out.v')
	res_digit := os.execute('${py2v_path} "${case_file}" -o "${out_file_digit}"')
	assert res_digit.exit_code == 0, 'transpilation failed: ${res_digit.output}'
	digit_text := os.read_file(out_file_digit) or {
		assert false, 'failed to read output file: ${err}'
		return
	}
	assert digit_text.contains('\nmodule m_123abc\n'), 'expected module m_123abc in generated output'
}

fn test_generated_line_length_limit() {
	repo_dir := detect_repo_root() or {
		assert false, err.msg()
		return
	}
	py2v_path := ensure_fresh_py2v(repo_dir) or {
		assert false, err.msg()
		return
	}
	case_file := os.join_path(repo_dir, 'tests', 'cases', 'long_wrap.py')

	res := os.execute('${py2v_path} "${case_file}"')
	assert res.exit_code == 0, 'transpilation failed: ${res.output}'
	lines := res.output.replace('\r\n', '\n').split('\n')
	for idx, line in lines {
		assert line.len <= 121, 'line ${idx + 1} exceeds 121 chars (${line.len})'
	}
}

fn test_init_has_no_return_type() {
	repo_dir := detect_repo_root() or {
		assert false, err.msg()
		return
	}
	py2v_path := ensure_fresh_py2v(repo_dir) or {
		assert false, err.msg()
		return
	}
	case_file := os.join_path(repo_dir, 'tests', 'cases', 'init_no_return.py')

	res := os.execute('${py2v_path} "${case_file}"')
	assert res.exit_code == 0, 'transpilation failed: ${res.output}'
	out := res.output.replace('\r\n', '\n')
	assert out.contains('fn (mut self Thing) __init__(x Any) {'), 'expected mut self constructor signature'
	assert !out.contains('__init__(x Any) Any'), '__init__ should not have a return type'
}

fn test_super_call_translation() {
	repo_dir := detect_repo_root() or {
		assert false, err.msg()
		return
	}
	py2v_path := ensure_fresh_py2v(repo_dir) or {
		assert false, err.msg()
		return
	}
	case_file := os.join_path(repo_dir, 'tests', 'cases', 'super_calls.py')

	res := os.execute('${py2v_path} "${case_file}"')
	assert res.exit_code == 0, 'transpilation failed: ${res.output}'
	out := res.output.replace('\r\n', '\n')
	assert out.contains('self.Base.__init__(value)'), 'expected super().__init__ translation to embedded base call'
	assert out.contains('return self.Base.greet()'), 'expected super().greet() translation to embedded base call'
	assert !out.contains('self.Exception.'), 'builtin Exception should not be emitted as embedded base call'
}

fn test_exception_union_alias_generation() {
	repo_dir := detect_repo_root() or {
		assert false, err.msg()
		return
	}
	py2v_path := ensure_fresh_py2v(repo_dir) or {
		assert false, err.msg()
		return
	}
	case_file := os.join_path(repo_dir, 'tests', 'cases', 'exception_union_init.py')

	res := os.execute('${py2v_path} "${case_file}"')
	assert res.exit_code == 0, 'transpilation failed: ${res.output}'
	out := res.output.replace('\r\n', '\n')
	assert out.contains('type WebDriverExceptions = BarException | WebDriverException | FooException'), 'expected union alias in __all__ order'
}
