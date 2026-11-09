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

	build := os.exec(['v', '.', '-o', py2v_path])
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
	res := os.exec(['v', 'fmt', '-w', tmp_file])
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
	defer {
		os.rm(py2v_path) or {}
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

		result := os.exec([py2v_path, case_file])
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
	defer {
		os.rm(py2v_path) or {}
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
	res_alpha := os.exec([py2v_path, case_file, '-o', out_file_alpha])
	assert res_alpha.exit_code == 0, 'transpilation failed: ${res_alpha.output}'
	alpha_text := os.read_file(out_file_alpha) or {
		assert false, 'failed to read output file: ${err}'
		return
	}
	assert alpha_text.contains('module foo_bar\n'), 'expected module foo_bar in generated output'

	out_dir_digit := os.join_path(tmp_root, '123abc')
	os.mkdir_all(out_dir_digit) or {
		assert false, 'failed to create temp output dir: ${err}'
		return
	}
	out_file_digit := os.join_path(out_dir_digit, 'out.v')
	res_digit := os.exec([py2v_path, case_file, '-o', out_file_digit])
	assert res_digit.exit_code == 0, 'transpilation failed: ${res_digit.output}'
	digit_text := os.read_file(out_file_digit) or {
		assert false, 'failed to read output file: ${err}'
		return
	}
	assert digit_text.contains('module m_123abc\n'), 'expected module m_123abc in generated output'
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
	defer {
		os.rm(py2v_path) or {}
	}

	case_file := os.join_path(repo_dir, 'tests', 'cases', 'long_wrap.py')

	res := os.exec([py2v_path, case_file])
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
	defer {
		os.rm(py2v_path) or {}
	}

	case_file := os.join_path(repo_dir, 'tests', 'cases', 'init_no_return.py')

	res := os.exec([py2v_path, case_file])
	assert res.exit_code == 0, 'transpilation failed: ${res.output}'
	out := res.output.replace('\r\n', '\n')
	assert out.contains('fn (mut self Thing) init(x int) {'), 'expected mut self constructor signature'
	assert !out.contains('init(x int) Any'), 'init should not have a return type'
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
	defer {
		os.rm(py2v_path) or {}
	}

	case_file := os.join_path(repo_dir, 'tests', 'cases', 'super_calls.py')

	res := os.exec([py2v_path, case_file])
	assert res.exit_code == 0, 'transpilation failed: ${res.output}'
	out := res.output.replace('\r\n', '\n')
	assert out.contains('self.Base.init(value)'), 'expected super().__init__ translation to embedded base call'
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
	defer {
		os.rm(py2v_path) or {}
	}

	case_file := os.join_path(repo_dir, 'tests', 'cases', 'exception_union_init.py')

	res := os.exec([py2v_path, case_file])
	assert res.exit_code == 0, 'transpilation failed: ${res.output}'
	out := res.output.replace('\r\n', '\n')
	assert out.contains('type WebDriverExceptions = BarException | WebDriverException | FooException'), 'expected union alias in __all__ order'
}

fn test_check_diagnostic_reads_located_and_unlocated_errors() {
	d := check_diagnostic('tmpmod/tmpmod.v:3:1: builder error: cannot import module "nosuch" (not found)') or {
		panic('not read')
	}
	assert d.file == 'tmpmod/tmpmod.v'
	assert d.message == 'builder error: cannot import module "nosuch" (not found)'
	e := check_diagnostic('out.v:4:9: error: undefined ident: `x`') or { panic('not read') }
	assert e.file == 'out.v' && e.message == 'undefined ident: `x`'
	u := check_diagnostic('error: cannot read file') or { panic('not read') }
	assert u.file == '' && u.message == 'error: cannot read file'
	b := check_diagnostic('builder error: something') or { panic('not read') }
	assert b.file == '' && b.message == 'builder error: something'
}

fn test_check_diagnostic_keeps_a_windows_drive_and_drops_crlf() {
	d := check_diagnostic('C:/work/out.v:3:1: builder error: cannot import module "x" (not found)\r') or {
		panic('not read')
	}
	assert d.file == 'C:/work/out.v'
	assert d.message == 'builder error: cannot import module "x" (not found)'
	w := check_diagnostic('C:\\work\\out.v:12:5: error: undefined ident: `y`\r') or {
		panic('not read')
	}
	assert w.file == 'C:\\work\\out.v' && w.message == 'undefined ident: `y`'
}

fn test_check_diagnostic_ignores_excerpts_warnings_and_notices() {
	for line in ["    8 | println('example: error: not a diagnostic')", "   12 | x := 'a:1:2: error: z'",
		'      |         ~~~~~', 'out.v:1:1: warning: unused variable',
		'out.v:1:1: notice: unused function', 'Details: error: in a detail line',
		'x:y:1: error: a location without a line number', ''] {
		assert check_diagnostic(line) == none, line
	}
}

fn test_record_check_run_counts_diagnostics_and_fails_closed() {
	mut two := CheckResult{}
	record_check_run(mut two, CheckRun{
		exit_code: 1
		output:    'out.v:1:1: error: first\n    1 | a\n      | ^\nDetails: more\nout.v:2:1: error: second\n... and 3 more errors\n'
	})
	assert two.error_count == 2 && two.first_error == 'first' && two.first_file == 'out.v'
	mut silent := CheckResult{}
	record_check_run(mut silent, CheckRun{
		exit_code: 1
		output:    'Unknown option: -shared\n'
	})
	assert silent.error_count == 1
	assert silent.first_error == 'v -check exited with status 1: Unknown option: -shared'
	mut empty := CheckResult{}
	record_check_run(mut empty, CheckRun{
		exit_code: 2
	})
	assert empty.error_count == 1
	assert empty.first_error == 'v -check exited with status 2 (no diagnostic output)'
	mut clean := CheckResult{}
	record_check_run(mut clean, CheckRun{
		output: 'out.v:1:1: warning: unused variable\n'
	})
	assert clean.error_count == 0 && clean.first_error == ''
}

// Package mode: a generated module importing a module that does not exist is
// reported by V's loader as a located builder error, which must count.
fn test_check_v_module_counts_a_missing_import() {
	work_dir := os.join_path(os.temp_dir(), 'py2v_check_import_${os.getpid()}')
	os.mkdir_all(os.join_path(work_dir, 'tmpmod')) or {
		assert false, 'failed to create temp dir: ${err}'
		return
	}
	defer {
		os.rmdir_all(work_dir) or {}
	}
	os.write_file(os.join_path(work_dir, 'tmpmod', 'tmpmod.v'),
		'module tmpmod\n\nimport nosuch_py2v_module\n\npub fn f() {}\n') or {
		assert false, 'failed to write module: ${err}'
		return
	}
	result := check_v_module(work_dir, 'tmpmod', 0)
	assert result.error_count == 1, 'a missing import must be counted, got ${result}'
	assert result.first_error.contains('cannot import module')
	assert result.first_file == 'tmpmod/tmpmod.v'
}
