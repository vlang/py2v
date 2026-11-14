module main

import os

fn test_replace_comp_identifier() {
	cases := [
		['', 'r', ''],
		['r', 'r', 'it'],
		['r+r', 'r', 'it+it'],
		['r', 'x', 'r'],
		['r', '', 'r'],
		['r rr r_tail tr r2 2r _r R r_', 'r', 'it rr r_tail tr r2 2r _r R r_'],
		['type_ type__ type_2 xtype_ x.type_ type_.x', 'type_', 'it type__ type_2 xtype_ x.it it.x'],
		['@fn + @fn_tail + fn + @type', '@fn', 'it + @fn_tail + fn + @type'],
		["'@type=\${@type}' + @type", '@type', "'@type=\${it}' + it"],
		['@match @match2 x.@match', '@match', 'it @match2 x.it'],
		['@ r @r', 'r', '@ it @r'],
		// A lowered getattr variable can occupy the same position as a literal field name.
		['x.r + r.x + r.r()', 'r', 'x.it + it.x + it.it()'],
		['r. r', 'r', 'it. it'],
		["'r' + r", 'r', "'r' + it"],
		['"r" + r', 'r', '"r" + it'],
		["r'r \${r}' + r", 'r', "r'r \${r}' + it"],
		["r'x' + r", 'r', "r'x' + it"],
		['r"r \${r}" + r', 'r', 'r"r \${r}" + it'],
		["r'r\\' + r", 'r', "r'r\\' + it"],
		["'a\\'r' + r", 'r', "'a\\'r' + it"],
		['"a\\"r" + r', 'r', '"a\\"r" + it'],
		["'a\\\\' + r", 'r', "'a\\\\' + it"],
		['`r` + r', 'r', '`r` + it'],
		['`\\`` + r', 'r', '`\\`` + it'],
		['`\${r}` + r', 'r', '`\${r}` + it'],
		["'r=\${r}'", 'r', "'r=\${it}'"],
		['"r=\${r}"', 'r', '"r=\${it}"'],
		["'\\\${r}' + r", 'r', "'\\\${r}' + it"],
		["'\${if r > 0 { r } else { 2 }}r' + r", 'r', "'\${if it > 0 { it } else { 2 }}r' + it"],
		["'\${{'r': r}}' + r", 'r', "'\${{'r': it}}' + it"],
		['\'\${"r=\${r}"}r=\${r}\'', 'r', '\'\${"r=\${it}"}r=\${it}\''],
		["'\${r'r \${r}'}\${r}'", 'r', "'\${r'r \${r}'}\${it}'"],
		["r + 'r", 'r', "it + 'r"],
		["'r $", 'r', "'r $"],
		["r + 'r\\", 'r', "it + 'r\\"],
		["'r \${r", 'r', "'r \${it"],
		['f(r) or { r }', 'r', 'f(it) or { it }'],
		['r := r; { r }', 'r', 'it := it; { it }'],
		// After a top-level colon an interpolation holds its format, not code.
		["'\${7:d}' + d", 'd', "'\${7:d}' + it"],
		["'\${x:x}' + x", 'x', "'\${it:x}' + it"],
		["'\${f(x: x):>5}'", 'x', "'\${f(it: it):>5}'"],
		["'\${{'x': x}[x]:x}'", 'x', "'\${{'x': it}[it]:x}'"],
		["'\${x:x", 'x', "'\${it:it"],
		// A colon that does not start a static format is code.
		["'\${if v := get(r) { v } else { r }}' + r", 'r', "'\${if v := get(it) { v } else { it }}' + it"],
		["'\${7:(r)}' + r", 'r', "'\${7:(it)}' + it"],
		["'\${{'x':x}[x]}'", 'x', "'\${{'x':it}[it]}'"],
		["'\${r:05.2f}\${f:>5}' + f", 'f', "'\${r:05.2f}\${it:>5}' + it"],
		["'\${f('\${x}', x: x)}'", 'x', "'\${f('\${it}', it: it)}'"],
	]
	for c in cases {
		assert replace_comp_identifier(c[0], c[1], 'it') == c[2], c[0]
	}
	assert replace_comp_identifier('n + n_max', 'n', 'subject') == 'subject + n_max'
}

fn test_is_comp_identifier() {
	for name in ['r', 'r2', '_r', '2r', 'type_', '@fn', '@type', '@match', '@_x', '@2'] {
		assert is_comp_identifier(name), name
	}
	for name in ['', '@', '@@fn', 'r.x', 'r x', '([a]).concat(a_part)', '(a, b)', "'r'"] {
		assert !is_comp_identifier(name), name
	}
}

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

fn test_code_prec_reads_the_top_level_operator_of_emitted_code() {
	assert code_prec('a + b * c') == 4
	assert code_prec('a * b') == 5
	assert code_prec('a && b || c') == 1
	assert code_prec('x < y') == 3
	assert code_prec('x is Dog') == 3
	assert cmp_operand('x is Dog') == '(x is Dog)'
	assert code_prec('(a + b)') == 10
	assert code_prec('math.powi(a - 1, 2)') == 10
	assert code_prec('xs[i - 1].len') == 10
	assert code_prec("'a + b'") == 10
	assert code_prec("'\${a + b} - c' + s") == 4
	assert code_prec('-a') == 9
	assert code_prec('+a') == 9
	assert code_prec('!a.contains(b)') == 9
	assert code_prec('if c { a } else { b }') == 0
	assert code_prec('f() or { 0 }') == 0
	assert as_receiver('s + t') == '(s + t)'
	assert as_receiver('-x') == '(-x)'
	assert as_receiver('+x') == '(+x)'
	assert as_receiver('s.trim_space()') == 's.trim_space()'
}

fn test_helper_name_avoids_taken_words_and_is_chosen_once() {
	mut r := new_module_registry()
	// The first free name, chosen once per module and kind
	assert r.helper_name('main', 'true_div', []) == 'py2v_true_div1'
	assert r.helper_name('main', 'true_div', ['py2v_true_div1']) == 'py2v_true_div1'
	// A word of the file being translated
	assert r.helper_name('a', 'true_div', ['x', 'py2v_true_div1']) == 'py2v_true_div2'
	// A word of any file of the module, with or without one of this file
	r.module_words['b'] << ['py2v_true_div1', 'py2v_true_div3']
	assert r.helper_name('b', 'true_div', ['py2v_true_div2']) == 'py2v_true_div4'
	// Another helper of the same module, and no one else's
	r.helper_names['c.other'] = 'py2v_true_div1'
	r.helper_names['d.other'] = 'py2v_true_div2'
	assert r.helper_name('c', 'true_div', []) == 'py2v_true_div2'
}

fn test_nonzero_int_literal_and_division_operand_type() {
	mut t := new_transpiler()
	two := Expr(Constant{
		value: 2
	})
	zero := Expr(Constant{
		value: 0
	})
	half := Expr(Constant{
		value: 0.5
	})
	minus_two := Expr(UnaryOp{
		op:      USub{}
		operand: &two
	})
	minus_zero := Expr(UnaryOp{
		op:      USub{}
		operand: &zero
	})
	not_two := Expr(UnaryOp{
		op:      Not{}
		operand: &two
	})
	name := Expr(Name{
		id: 'n'
	})
	assert is_nonzero_int_literal(two)
	assert is_nonzero_int_literal(minus_two)
	assert !is_nonzero_int_literal(zero)
	assert !is_nonzero_int_literal(Expr(Constant{
		value: i64(0)
	}))
	assert is_nonzero_int_literal(Expr(Constant{
		value: i64(5000000000)
	}))
	assert !is_nonzero_int_literal(minus_zero)
	assert !is_nonzero_int_literal(half)
	assert !is_nonzero_int_literal(not_two)
	assert !is_nonzero_int_literal(name)
	assert is_v_int_type(t.division_operand_type(two, t.infer_expr_type(two)))
	assert is_v_int_type(t.division_operand_type(minus_two, t.infer_expr_type(minus_two)))
	assert !is_v_int_type(t.division_operand_type(half, t.infer_expr_type(half)))
	assert !is_v_int_type(t.division_operand_type(name, t.infer_expr_type(name)))
	t.var_types['n'] = 'i64'
	assert is_v_int_type(t.division_operand_type(name, t.infer_expr_type(name)))
	t.var_types['n'] = 'f64'
	assert !is_v_int_type(t.division_operand_type(name, t.infer_expr_type(name)))
	t.var_types['n'] = 'string'
	assert !is_v_int_type(t.division_operand_type(name, t.infer_expr_type(name)))
}

fn test_runtime_helper_name_and_declaration() {
	assert runtime_helper_declaration('true_div', 'h').contains('fn h(a f64, b f64) f64 {')
	mut t := new_transpiler()
	assert t.runtime_helper('true_div') == 'py2v_true_div1'
	assert t.runtime_helper('true_div') == 'py2v_true_div1'
	assert t.helpers_used == ['true_div']
	// The next module this transpiler emits starts without it
	t.module_name = 'other'
	assert !t.visit_module(Module{}).contains('py2v_true_div')
}

fn test_as_f64_argument_converts_what_v_does_not() {
	mut t := new_transpiler()
	name := Expr(Name{
		id: 'n'
	})
	minus := Expr(UnaryOp{
		op:      USub{}
		operand: &name
	})
	t.var_types['n'] = 'int'
	assert as_f64_argument(t.division_operand_type(name, t.infer_expr_type(name)), 'n') == 'n'
	assert as_f64_argument(t.division_operand_type(minus, t.infer_expr_type(minus)), '-n') == '-n'
	t.var_types['n'] = 'i64'
	assert as_f64_argument(t.division_operand_type(name, t.infer_expr_type(name)), 'n') == 'f64(n)'
	assert as_f64_argument(t.division_operand_type(minus, t.infer_expr_type(minus)), '-n') == 'f64(-n)'
}

fn test_a_division_is_a_float_only_when_both_operands_are_ints() {
	mut t := new_transpiler()
	t.var_types['n'] = 'int'
	n := Expr(Name{
		id: 'n'
	})
	u := Expr(Name{
		id: 'u'
	})
	minus_n := Expr(UnaryOp{
		op:      USub{}
		operand: &n
	})
	inverted_n := Expr(UnaryOp{
		op:      Invert{}
		operand: &n
	})
	assert t.infer_expr_type(Expr(BinOp{ left: &n, op: Div{}, right: &n })) == 'f64'
	assert t.infer_expr_type(Expr(BinOp{ left: &minus_n, op: Div{}, right: &inverted_n })) == 'f64'
	assert t.infer_expr_type(Expr(BinOp{ left: &n, op: Div{}, right: &u })) == ''
	assert t.infer_expr_type(Expr(BinOp{ left: &u, op: Div{}, right: &n })) == ''
	assert t.infer_expr_type(Expr(BinOp{ left: &n, op: Mult{}, right: &n })) != 'f64'
	// A lambda parameter named like an int variable is not that variable
	t.lambda_params['n'] = 1
	assert t.infer_expr_type(Expr(BinOp{ left: &n, op: Div{}, right: &n })) != 'f64'
	assert t.infer_expr_type(Expr(BinOp{ left: &minus_n, op: Div{}, right: &n })) != 'f64'
}
