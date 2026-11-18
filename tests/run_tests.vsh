#!/usr/bin/env -S v

import os
import arrays.parallel
import time
import runtime

// Unified py2v test runner.
//
// Replaces the previous run_tests.sh / run_tests.ps1 pair with a single V script
// so both platforms run exactly the same logic. Invoke it with:
//
//   v tests/run_tests.vsh
//
// Environment:
//   VERBOSE=1    print expected/generated excerpts for failing cases
//   PY2V=<path>  use an explicit py2v binary instead of the one beside this script

// resolve_py2v returns the py2v binary to exercise. An explicit PY2V wins;
// otherwise the sibling binary is used, preferring `.exe` on Windows.
fn resolve_py2v() string {
	if override := getenv_opt('PY2V') {
		return override
	}
	bin := join_path(project_dir, 'py2v')
	if !exists(bin) && exists(bin + '.exe') {
		return bin + '.exe'
	}
	return bin
}

// normalize_v_code formats generated and expected V through `v fmt` so that
// cosmetic differences do not fail a test. Both sides go through the same
// formatting pass; if formatting fails, the input is returned unchanged.
fn normalize_v_code(code string, seq int) string {
	tmp := os.join_path(os.temp_dir(), 'py2v_fmt_${os.getpid()}_${seq}.v')
	os.write_file(tmp, code) or { return code }
	defer {
		os.rm(tmp) or {}
	}
	res := os.exec(['v', 'fmt', '-w', tmp])
	if res.exit_code == 0 {
		return (os.read_file(tmp) or { code }).replace('\r', '')
	}
	return code.replace('\r', '')
}

// report prints a single PASS/FAIL/SKIP line.
fn report(status string, case_name string, detail string) {
	println(status + ' ' + case_name + detail)
}

// fail_line formats one entry of the trailing failure list.
fn fail_line(status string, case_name string, detail string) string {
	mut line := status + ' ' + case_name + detail
	return line
}

// excerpt returns the first `n` lines of `text`, for compact failure output.
fn excerpt(text string) string {
	return excerpt_n(text, 20)
}

fn excerpt_n(text string, n int) string {
	lines := text.split('\n')
	limit := if lines.len < n { lines.len } else { n }
	return lines[..limit].join('\n')
}

// run_generated separates compiler diagnostics from the program's output.
fn run_generated(source string) os.Result {
	bin := source + $if windows { '.exe' } $else { '.bin' }
	build := os.exec([@VEXE, '-path', '@vlib|${project_dir}|@vmodules', '-o', bin, source])
	if build.exit_code != 0 {
		return build
	}
	return os.exec([bin])
}

// compare_execution checks observable output against CPython, beyond fixture text.
fn compare_execution(args []string) os.Result {
	translation := os.exec([args[0], args[2]])
	if translation.exit_code != 0 {
		return translation
	}
	os.write_file(args[3], translation.output) or {
		return os.Result{ exit_code: 1, output: err.msg() }
	}
	// UTF-8 mode: on Windows CPython would otherwise use the console code page.
	python_run := os.exec([args[1], '-X', 'utf8', '-I', args[2]])
	v_run := run_generated(args[3])
	if python_run.exit_code == 0 && v_run.exit_code == 0
		&& python_run.output.replace('\r', '') == v_run.output.replace('\r', '') {
		return os.Result{}
	}
	return os.Result{
		exit_code: 1
		output:    'CPython (exit ${python_run.exit_code}):\n${python_run.output}\nV (exit ${v_run.exit_code}):\n${v_run.output}'
	}
}

const script_dir = os.dir(os.abs_path(@FILE))
const project_dir = os.dir(script_dir)
const cases_dir = os.join_path(script_dir, 'cases')
const expected_dir = os.join_path(script_dir, 'expected')
const package_fixtures = ['pkg_imports', 'pkg_lib_main', 'pkg_multi', 'pkg_multi2', 'pkg_true_div',
	'pkg_init_execution', 'pkg_private_names', 'pkg_call_defaults']!

mut py2v := resolve_py2v()

// Build py2v when it is missing so a fresh checkout is testable.
if !os.exists(py2v) {
	println('Building py2v...')
	res := os.exec(['v', project_dir, '-o', py2v])
	if res.exit_code != 0 {
		eprintln('ERROR: failed to build py2v')
		eprintln(res.output)
		exit(1)
	}
}

suite_watch := time.new_stopwatch()
println('Running tests...')
println('')

mut case_files := os.ls(cases_dir) or { []string{} }
mut case_names := case_files.filter(it.ends_with('.py'))
case_names.sort()

mut passed := 0
mut failed := 0
mut skipped := 0
mut failures := []string{}
mut verbose := os.getenv('VERBOSE') == '1'
mut fmt_seq := 0

for entry in case_names {
	case_name := entry.trim_string_right('.py')
	expected_file := os.join_path(expected_dir, case_name + '.v')
	case_path := os.join_path(cases_dir, entry)

	if !os.exists(expected_file) {
		report('SKIP', case_name, ' (no expected file)')
		skipped++
		continue
	}

	res := os.exec([py2v, case_path])
	if res.exit_code != 0 {
		report('FAIL', case_name, ' (transpilation error)')
		failed++
		failures << fail_line('FAIL', case_name, ' (transpilation error)')
		continue
	}

	expected := os.read_file(expected_file) or { '' }
	fmt_seq++
	generated := normalize_v_code(res.output, fmt_seq)
	fmt_seq++
	expected_norm := normalize_v_code(expected, fmt_seq)

	if generated == expected_norm {
		report('PASS', case_name, '')
		passed++
		continue
	}

	report('FAIL', case_name, ' (output mismatch)')
	failed++
	failures << fail_line('FAIL', case_name, ' (output mismatch)')
	if verbose {
		println('--- Expected ---')
		println(excerpt(expected_norm))
		println('--- Generated ---')
		println(excerpt(generated))
		println('----------------')
	}
}

// Initializers must run, rather than merely putting positional arguments into
// fields. Compare actual program output, including constructor calls in init.
init_root := os.join_path(os.temp_dir(), 'py2v_init_${os.getpid()}')
os.mkdir_all(init_root) or { panic(err) }
init_source := os.join_path(cases_dir, 'init_execution.py')
init_translation := os.exec([py2v, init_source])
init_v := os.join_path(init_root, 'main.v')
os.write_file(init_v, init_translation.output) or { panic(err) }
init_expected := os.read_file(os.join_path(script_dir, 'baseline', 'init_execution.out')) or {
	panic(err)
}
init_v_run := run_generated(init_v)
python := $if windows { 'python' } $else { 'python3' }

dynamic_cases := ['dynamic_container_elements', 'dynamic_membership', 'dynamic_comprehensions',
	'dynamic_methods', 'dynamic_or_default', 'dynamic_stores', 'dynamic_runtime_returns',
	'dynamic_attributes', 'dynamic_truth', 'dynamic_mixed_membership', 'dynamic_boxed_bytes',
	'dynamic_unpacking', 'dynamic_optional', 'dynamic_conditional', 'native_map_types',
	'truth_container_values', 'truth_optional_values', 'truth_dynamic_negation', 'truth_dynamic_lazy',
	'truth_optional_instances', 'truth_runtime_lists', 'truth_optional_calls', 'truth_optional_dynamic',
	'truth_literals', 'truth_storage_default', 'truth_mixed_list_body', 'truth_mixed_list_else',
	'truth_mixed_list_default', 'truth_boxed_floats', 'mixed_display_dynamic', 'json_runtime_options',
	'truth_bool_context', 'truth_optional_returns', 'truth_native_objects', 'truth_local_class_hooks']
dynamic_root := os.join_path(os.temp_dir(), 'py2v_dynamic_${os.getpid()}')
os.mkdir_all(dynamic_root) or { panic(err) }
mut dynamic_args := [][]string{}
for name in dynamic_cases {
	dynamic_args << [py2v, python, os.join_path(cases_dir, name + '.py'),
		os.join_path(dynamic_root, name.replace('/', '_') + '.v')]
}
dynamic_results := parallel.amap(dynamic_args, compare_execution, workers: 2)
for i, result in dynamic_results {
	name := 'runtime execution: ' + dynamic_cases[i]
	if result.exit_code == 0 {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println(result.output)
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
// This program needs native dict aliasing that pyrt.box cannot preserve. Its
// compilation rejection is a guard against silently compiling wrong code, NOT
// a passing CPython/V execution comparison.
alias_name := 'runtime boundary: reject native map alias copy'
alias_source := os.join_path(cases_dir, 'dynamic_errors', 'container_alias.py')
alias_v := os.join_path(dynamic_root, 'native_alias.v')
alias_translation := os.exec([py2v, alias_source])
mut alias_ok := alias_translation.exit_code == 0
if alias_ok {
	os.write_file(alias_v, alias_translation.output) or { panic(err) }
	alias_python := os.exec([python, '-X', 'utf8', '-I', alias_source])
	alias_syntax := os.exec([@VEXE, '-check-syntax', alias_v])
	alias_generated := run_generated(alias_v)
	alias_ok = alias_python.exit_code == 0 && alias_python.output.trim_space() == '2'
		&& alias_syntax.exit_code == 0 && alias_generated.exit_code != 0
		&& alias_generated.output.contains('cannot cast `map[string]map[string]int` to `Any`')
}
if alias_ok {
	report('PASS', alias_name, '')
	passed++
	report('SKIP', 'runtime execution: dynamic_errors/container_alias',
		' (native mutable alias semantics not implemented)')
	skipped++
} else {
	report('FAIL', alias_name, '')
	failed++
	failures << fail_line('FAIL', alias_name, '')
}
os.rmdir_all(dynamic_root) or { panic(err) }

boundary_name := 'runtime execution: pyrt/box_boundary_test.v'
boundary_run := os.exec([@VEXE, 'test', os.join_path(project_dir, 'pyrt', 'box_boundary_test.v')])
if boundary_run.exit_code == 0 {
	report('PASS', boundary_name, '')
	passed++
} else {
	report('FAIL', boundary_name, '')
	println(boundary_run.output)
	failed++
	failures << fail_line('FAIL', boundary_name, '')
}

init_py_run := os.exec([python, '-B', init_source])
init_name := 'initializers: single-file execution'
if init_translation.exit_code == 0 && init_v_run.exit_code == 0 && init_py_run.exit_code == 0
	&& init_v_run.output.replace('\r', '') == init_expected
	&& init_py_run.output.replace('\r', '') == init_expected {
	report('PASS', init_name, '')
	passed++
} else {
	report('FAIL', init_name, '')
	println(excerpt_n(init_v_run.output, 20))
	println(excerpt_n(init_py_run.output, 20))
	failed++
	failures << fail_line('FAIL', init_name, '')
}
literal_name := 'initializers: classes without init keep literals'
if init_translation.output.contains('p := Plain{}')
	&& init_translation.output.contains('inherited := PlainChild{\n\t\tBase: Base{ value: 11 }\n\t}') {
	report('PASS', literal_name, '')
	passed++
} else {
	report('FAIL', literal_name, '')
	failed++
	failures << fail_line('FAIL', literal_name, '')
}
os.rmdir_all(init_root) or { panic(err) }

// A dictionary get result may be None. Defaults run even for existing keys and
// can change the dictionary before its value is read. Each case gets its own binary.
call_results_root := os.join_path(os.temp_dir(), 'py2v_call_results_${os.getpid()}')
os.mkdir_all(call_results_root) or { panic(err) }
call_results_cases := ['dict_get_missing', 'dict_get_eager', 'dict_get_chain', 'dict_get_receiver',
	'dict_get_mutating', 'dict_get_compare', 'with_return', 'rebound_optional_params',
	'argparse_join_value', 'join_string_iterable', 'subparser_parameter']
mut execution_args := [][]string{}
for name in call_results_cases {
	execution_args << [py2v, python, os.join_path(cases_dir, name + '.py'),
		os.join_path(call_results_root, name + '.v')]
}
execution_results := parallel.amap(execution_args, compare_execution, workers: runtime.nr_jobs())
for i, result in execution_results {
	name := 'call results: ${call_results_cases[i]} execution'
	if result.exit_code == 0 {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println(result.output)
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
os.rmdir_all(call_results_root) or { panic(err) }

// Definite assignment must preserve both Python results and unproven paths.
assignment_root := os.join_path(os.temp_dir(), 'py2v_assignment_${os.getpid()}')
os.mkdir_all(assignment_root) or { panic(err) }
assignment_source := os.join_path(cases_dir, 'definite_assignment.py')
assignment_translation := os.exec([py2v, assignment_source])
assignment_v := os.join_path(assignment_root, 'main.v')
os.write_file(assignment_v, assignment_translation.output) or { panic(err) }
assignment_run := run_generated(assignment_v)
assignment_python := os.exec([python, '-B', assignment_source])
assignment_expected := '[2, 3]\n[4]\n[5]\n[7]\n[8]\n[10]\n[11]\n'
assignment_name := 'scope: proven assignment execution'
if assignment_translation.exit_code == 0 && assignment_run.exit_code == 0
	&& assignment_python.exit_code == 0
	&& assignment_run.output.replace('\r', '') == assignment_expected
	&& assignment_python.output.replace('\r', '') == assignment_expected {
	report('PASS', assignment_name, '')
	passed++
} else {
	report('FAIL', assignment_name, '')
	println(excerpt_n(assignment_run.output, 20))
	failed++
	failures << fail_line('FAIL', assignment_name, '')
}
os.rmdir_all(assignment_root) or { panic(err) }
assignment_analysis := os.exec([python, '-B', os.join_path(script_dir, 'definite_assignment_test.py')])
assignment_analysis_name := 'scope: definite assignment analysis'
if assignment_analysis.exit_code == 0 {
	report('PASS', assignment_analysis_name, '')
	passed++
} else {
	report('FAIL', assignment_analysis_name, '')
	println(excerpt_n(assignment_analysis.output, 20))
	failed++
	failures << fail_line('FAIL', assignment_analysis_name, '')
}

// Compile each builtin witness once and compare its output with CPython.
for witness in [
	['builtin_frozenset',
		'0 2 2 2 1\nTrue False\n2 0 0\nleft\nright\nTrue\nfrozenset({1.0})\nfrozenset({-0.0})\nfrozenset({1.0})\nfrozenset({-0.0})\nFalse True\nunhashable\nmember error\nnot iterable\n'],
	['builtin_frozenset_shadow', '22\n'],
	['builtin_frozenset_mutable_member', 'True\nTrue\nFalse\n'],
	['builtin_typing_cast', '1\nword\n3\nonce\n8\n9\n'],
	['builtin_typing_union_cast', '1\nword\n2\n3\n7\n'],
	['builtin_typing_forward_cast', '1\n2\n3\n4\n5\n'],
	['builtin_exit_shadow', '22\n'],
] {
	builtin_root := os.join_path(os.temp_dir(), 'py2v_builtin_${witness[0]}_${os.getpid()}')
	os.mkdir_all(builtin_root) or { panic(err) }
	source := os.join_path(cases_dir, witness[0] + '.py')
	translated := os.exec([py2v, source])
	generated := os.join_path(builtin_root, 'main.v')
	binary := os.join_path(builtin_root, 'probe' + $if windows { '.exe' } $else { '' })
	os.write_file(generated, translated.output) or { panic(err) }
	built := os.exec([@VEXE, '-path', project_dir + '|@vlib|@vmodules', '-o', binary, generated])
	native := if built.exit_code == 0 { os.exec([binary]) } else { built }
	cpython := os.exec([python, '-B', source])
	name := 'builtins: ${witness[0]} execution'
	if translated.exit_code == 0 && native.exit_code == 0 && cpython.exit_code == 0
		&& native.output.replace('\r', '') == witness[1]
		&& cpython.output.replace('\r', '') == witness[1] {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println(excerpt_n(native.output, 20))
		failed++
		failures << fail_line('FAIL', name, '')
	}
	os.rmdir_all(builtin_root) or { panic(err) }
}
// All exit modes share one compiled fixture and compare status as well as output.
exit_root := os.join_path(os.temp_dir(), 'py2v_builtin_exit_${os.getpid()}')
os.mkdir_all(exit_root) or { panic(err) }
exit_source := os.join_path(cases_dir, 'builtin_exit.py')
exit_translated := os.exec([py2v, exit_source])
exit_generated := os.join_path(exit_root, 'main.v')
exit_binary := os.join_path(exit_root, 'probe' + $if windows { '.exe' } $else { '' })
os.write_file(exit_generated, exit_translated.output) or { panic(err) }
exit_built := os.exec([@VEXE, '-path', project_dir + '|@vlib|@vmodules', '-o', exit_binary,
	exit_generated])
for mode in ['caught', 'zero', 'int', 'true', 'false', 'none', 'message', 'direct_finally',
	'sys_finally', 'nested_finally', 'nested_cleanups'] {
	native := if exit_built.exit_code == 0 { os.exec([exit_binary, mode]) } else { exit_built }
	cpython := os.exec([python, '-B', exit_source, mode])
	expected_status := match mode {
		'int' { 7 }
		'sys_finally' { 4 }
		'nested_finally' { 3 }
		'nested_cleanups' { 2 }
		'true', 'message', 'direct_finally' { 1 }
		else { 0 }
	}
	expected_output := match mode {
		'caught' { 'caught 3\nbase message\ndefault\nnone\n' }
		'message' { 'message\n' }
		'direct_finally' { 'direct cleanup\ndirect message\n' }
		'sys_finally' { 'argument evaluated\nsys cleanup\n' }
		'nested_finally' { 'outer cleanup\n' }
		'nested_cleanups' { 'inner cleanup\nouter cleanup\n' }
		else { '' }
	}
	name := 'builtins: exit ${mode}'
	if exit_translated.exit_code == 0 && native.exit_code == expected_status
		&& cpython.exit_code == expected_status
		&& native.output.replace('\r', '') == expected_output
		&& cpython.output.replace('\r', '') == expected_output {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println('status ${native.exit_code}, expected ${expected_status}')
		println(excerpt_n(native.output, 20))
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
os.rmdir_all(exit_root) or { panic(err) }
exit_analysis := os.exec([python, '-B', os.join_path(script_dir, 'exit_lowering_test.py')])
exit_analysis_name := 'builtins: exit resolution and refusal cases'
if exit_analysis.exit_code == 0 {
	report('PASS', exit_analysis_name, '')
	passed++
} else {
	report('FAIL', exit_analysis_name, '')
	println(excerpt_n(exit_analysis.output, 20))
	failed++
	failures << fail_line('FAIL', exit_analysis_name, '')
}
cast_analysis := os.exec([python, '-B', os.join_path(script_dir, 'typing_cast_test.py')])
cast_analysis_name := 'builtins: typing cast effects and refusal cases'
if cast_analysis.exit_code == 0 {
	report('PASS', cast_analysis_name, '')
	passed++
} else {
	report('FAIL', cast_analysis_name, '')
	println(excerpt_n(cast_analysis.output, 20))
	failed++
	failures << fail_line('FAIL', cast_analysis_name, '')
}
frozen_unit := os.exec([@VEXE, 'test', os.join_path(project_dir, 'pyrt', 'frozenset_from_test.v')])
frozen_unit_name := 'builtins: immutable set identity and copying'
if frozen_unit.exit_code == 0 {
	report('PASS', frozen_unit_name, '')
	passed++
} else {
	report('FAIL', frozen_unit_name, '')
	println(excerpt_n(frozen_unit.output, 20))
	failed++
	failures << fail_line('FAIL', frozen_unit_name, '')
}

// An initializer that cannot start from a valid zero struct must fail visibly.
// Keep these negative cases out of the generated-code expectation loop.
init_errors := os.join_path(os.temp_dir(), 'py2v_init_errors_${os.getpid()}', 'main')
os.mkdir_all(init_errors) or { panic(err) }
for c in [['required_reference', 'Parent', 'child']] {
	source := os.join_path(cases_dir, 'init_errors', c[0] + '.py')
	generated := os.join_path(init_errors, c[0] + '.v')
	res := os.exec([py2v, source, '--check', '-o', generated])
	compiler := os.exec([@VEXE, '-check', generated])
	diagnostic := compiler.output.to_lower()
	name := 'initializers: reject ${c[0]}'
	if res.exit_code != 0 && compiler.exit_code != 0 && diagnostic.contains(c[1].to_lower())
		&& diagnostic.contains(c[2]) {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, ' (exit ${res.exit_code})')
		println(excerpt_n(res.output, 20))
		println(excerpt_n(compiler.output, 20))
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
os.rmdir_all(os.dir(init_errors)) or { panic(err) }

// Multi-module package fixtures: a Python package must transpile to a V
// project whose cross-module references resolve and which `v -check` accepts.
//
// The check goes through `py2v --package ... --check`, which compiles each
// generated module through a synthetic entry point. Handing the output tree to
// `v -shared -check <dir>` instead would be useless: V only walks files
// reachable from a main module, so a library tree reports success while nothing
// in it has been looked at.
for pkg in package_fixtures {
	pkg_dir := os.join_path(cases_dir, pkg)
	if !os.is_dir(pkg_dir) {
		continue
	}
	out_dir := os.join_path(os.temp_dir(),
		'py2v_pkg_${pkg}_${os.getpid()}')
	res := os.exec([py2v, '--package', pkg_dir, '-o', out_dir, '--check'])
	if res.exit_code != 0 {
		report('FAIL', pkg, ' (multi-module does not compile)')
		// The failing run prints the per-module table followed by the first
		// diagnostics.
		println(excerpt_n(res.output, 20))
		failed++
		failures << fail_line('FAIL', pkg, ' (multi-module does not compile)')
	} else {
		report('PASS', pkg, ' (multi-module)')
		passed++
		if pkg == 'pkg_call_defaults' {
			for stem in ['use', 'keywords', 'float_defaults', 'local_defaults', 'keyword_only'] {
				actual := os.read_file(os.join_path(out_dir, 'py_pkg_call_defaults_consumer', stem + '.v')) or { '' }
				expected := os.read_file(os.join_path(expected_dir, pkg, 'consumer', stem + '.v')) or { '' }
				golden_name := 'call defaults: package fixture ' + stem
				if actual.len > 0 && expected.len > 0 && actual.replace('\r', '') == expected.replace('\r', '') {
					report('PASS', golden_name, '')
					passed++
				} else {
					report('FAIL', golden_name, '')
					failed++
					failures << fail_line('FAIL', golden_name, '')
				}
			}
			entry := os.join_path(out_dir, 'defaults_main.v')
			os.write_file(entry, 'module main\n\nimport py_pkg_call_defaults_consumer\n\nfn main() {\n\tpy_pkg_call_defaults_consumer.run()\n}\n') or { panic(err) }
			v_run := run_generated(entry)
			py_run := os.exec([python, '-I', '-B', '-c',
				'import sys; sys.path.insert(0, sys.argv[1]); from pkg_call_defaults.consumer.use import run; run()',
				cases_dir])
			name := 'call defaults: package execution'
			if v_run.exit_code == 0 && py_run.exit_code == 0 && py_run.output.len > 0
				&& v_run.output.replace('\r', '') == py_run.output.replace('\r', '') {
				report('PASS', name, '')
				passed++
			} else {
				report('FAIL', name, '')
				println(excerpt_n(v_run.output, 20))
				println(excerpt_n(py_run.output, 20))
				failed++
				failures << fail_line('FAIL', name, '')
			}
		}
		if pkg == 'pkg_imports' {
			for fixture in ['uses_bound_names', 'uses_imported_values'] {
				generated := os.read_file(os.join_path(out_dir, 'py_pkg_imports', fixture + '.v')) or { panic(err) }
				expected := os.read_file(os.join_path(expected_dir, pkg, fixture + '.v')) or { panic(err) }
				fmt_seq++
				generated_norm := normalize_v_code(generated, fmt_seq)
				fmt_seq++
				name := 'imports: ${fixture}'
				if generated_norm == normalize_v_code(expected, fmt_seq) {
					report('PASS', name, '')
					passed++
				} else {
					report('FAIL', name, '')
					failed++
					failures << fail_line('FAIL', name, '')
				}
			}
			entry := os.join_path(out_dir, 'import_main.v')
			os.write_file(entry, 'module main\nimport py_pkg_imports\nfn main() {\nprintln(py_pkg_imports.bound_names_total())\nprintln(py_pkg_imports.shadow_module(3))\nprintln(py_pkg_imports.shadow_import())\nprintln(py_pkg_imports.imported_values_total())\n}\n') or { panic(err) }
			v_run := run_generated(entry)
			py_run := os.exec([python, '-B', '-c',
				'import sys; sys.path.insert(0, sys.argv[1]); from pkg_imports.uses_bound_names import bound_names_total, shadow_module, shadow_import; from pkg_imports.uses_imported_values import imported_values_total; print(bound_names_total()); print(shadow_module(3)); print(shadow_import()); print(imported_values_total())',
				cases_dir])
			name_run := 'imports: execution'
			if v_run.exit_code == 0 && py_run.exit_code == 0
				&& v_run.output.replace('\r', '') == '30\n4\n4\n29\n'
				&& py_run.output.replace('\r', '') == '30\n4\n4\n29\n' {
				report('PASS', name_run, '')
				passed++
			} else {
				report('FAIL', name_run, '')
				println(excerpt_n(v_run.output, 20))
				println(excerpt_n(py_run.output, 20))
				failed++
				failures << fail_line('FAIL', name_run, '')
			}
		}
		if pkg == 'pkg_init_execution' {
			entry := os.join_path(out_dir, 'constructor_main.v')
			os.write_file(entry,
				'module main\n\nimport py_pkg_init_execution\n\nfn main() {\n\tpy_pkg_init_execution.run()\n}\n') or {
				panic(err)
			}
			expected := os.read_file(os.join_path(script_dir, 'baseline', 'pkg_init_execution.out')) or {
				panic(err)
			}
			v_run := run_generated(entry)
			py_run := os.exec([python, '-B', '-c',
				'import sys; sys.path.insert(0, sys.argv[1]); from pkg_init_execution.use import run; run()',
				cases_dir])
			name := 'initializers: package execution'
			if v_run.exit_code == 0 && py_run.exit_code == 0
				&& v_run.output.replace('\r', '') == expected
				&& py_run.output.replace('\r', '') == expected {
				report('PASS', name, '')
				passed++
			} else {
				report('FAIL', name, '')
				println(excerpt_n(v_run.output, 20))
				println(excerpt_n(py_run.output, 20))
				failed++
				failures << fail_line('FAIL', name, '')
			}
		}
	}
	os.rmdir_all(out_dir) or { panic(err) }
}

// Unknown external classes retain the complete previous emission, even when
// that emission does not compile. They are outside the scanned package.
external_out := os.join_path(os.temp_dir(), 'py2v_init_external_${os.getpid()}')
external := os.exec([py2v, '--package', os.join_path(cases_dir, 'pkg_init_external'), '-o',
	external_out])
external_code := os.read_file(os.join_path(external_out, 'py_pkg_init_external', 'use.v')) or {
	''
}
external_expected := os.read_file(os.join_path(script_dir, 'baseline', 'pkg_init_external.v.txt')) or {
	panic(err)
}
external_name := 'initializers: unknown external class is unchanged'
if external.exit_code == 0 && external_code.replace('\r', '') == external_expected {
	report('PASS', external_name, '')
	passed++
} else {
	report('FAIL', external_name, '')
	println(excerpt_n(external.output, 20))
	println(excerpt_n(external_code, 20))
	failed++
	failures << fail_line('FAIL', external_name, '')
}
os.rmdir_all(external_out) or { panic(err) }

// Single-file `--check` must compile the generated file: code that does not
// compile fails, with and without -o, also when the output directory's name is
// not the module's (`foo-bar/` holds `module foo_bar`); clean code passes, also
// beside an unrelated broken .v file, which the check must not compile.
check_root := os.join_path(os.temp_dir(), 'py2v_single_check_${os.getpid()}')
for sub in ['foo-bar', 'clean', 'beside'] {
	os.mkdir_all(os.join_path(check_root, sub)) or { panic(err) }
}
broken_py := os.join_path(check_root, 'broken.py')
os.write_file(broken_py, 'def f() -> int:\n    return undefined_name_py2v\n') or { panic(err) }
os.write_file(os.join_path(check_root, 'beside', 'unrelated.v'),
	'module beside\n\nfn g() int {\n\treturn undefined_in_sibling\n}\n') or { panic(err) }
hello_py := os.join_path(cases_dir, 'hello_world.py')
single_checks := [
	['broken (stdout)', broken_py, '', '1'],
	['broken (-o)', broken_py, os.join_path(check_root, 'out.v'), '1'],
	['broken (-o foo-bar/)', broken_py, os.join_path(check_root, 'foo-bar', 'out.v'), '1'],
	['clean (-o)', hello_py, os.join_path(check_root, 'clean', 'hello.v'), '0'],
	['clean beside a broken file', hello_py, os.join_path(check_root, 'beside', 'hello.v'), '0'],
]
for c in single_checks {
	mut args := [py2v, c[1], '--check']
	if c[2] != '' {
		args << ['-o', c[2]]
	}
	res := os.exec(args)
	name := 'single-file check: ${c[0]}'
	ok := res.exit_code.str() == c[3] && (c[3] == '0' || res.output.contains('undefined_name_py2v'))
	if ok {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, ' (exit ${res.exit_code}, expected ${c[3]})')
		println(excerpt_n(res.output, 20))
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
for kind in ['float', 'int'] {
	source := os.join_path(cases_dir, 'rebound_optional_${kind}.py')
	out := os.join_path(check_root, 'numeric_${kind}.v')
	res := os.exec([py2v, source, '--check', '-o', out])
	name := 'optional numbers: ${kind} refuses coercion'
	if res.exit_code == 1 && res.output.contains('mutable arguments are only allowed') {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, ' (exit ${res.exit_code}, expected a numeric refusal)')
		println(excerpt_n(res.output, 20))
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
os.rmdir_all(check_root) or { panic(err) }

// A compiler that exits non-zero without printing a V diagnostic must still fail
// the check: here py2v itself stands in for V and refuses `-shared`. And a
// compiler that prints more than a pipe holds must not hang it: `loud` prints
// about 300 KB and exits 1.
compiler_root := os.join_path(os.temp_dir(), 'py2v_check_compiler_${os.getpid()}')
os.mkdir_all(compiler_root) or { panic(err) }
loud_src := os.join_path(compiler_root, 'loud.v')
os.write_file(loud_src, "fn main() {\n\tline := 'x'.repeat(200)\n\tfor _ in 0 .. 1500 {\n\t\tprintln(line)\n\t}\n\texit(1)\n}\n") or {
	panic(err)
}
loud_bin := os.join_path(compiler_root, $if windows { 'loud.exe' } $else { 'loud' })
loud_build := os.exec([@VEXE, '-o', loud_bin, loud_src])
if loud_build.exit_code != 0 {
	panic('could not build the loud compiler: ${loud_build.output}')
}
old_v := os.getenv('V')
for c in [['fails closed without a diagnostic', py2v], ['drains a large output', loud_bin]] {
	os.setenv('V', c[1], true)
	res := os.exec([py2v, hello_py, '--check'])
	name := 'single-file check: ${c[0]}'
	if res.exit_code == 1 && res.output.contains('v -check exited with status') {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, ' (exit ${res.exit_code})')
		println(excerpt_n(res.output, 20))
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
os.setenv('V', old_v, true)
os.rmdir_all(compiler_root) or { panic(err) }

// When the Python frontend fails, py2v must say why: a file with a syntax error
// and a file that does not exist both print the frontend's message and exit 1.
frontend_root := os.join_path(os.temp_dir(), 'py2v_frontend_errors_${os.getpid()}')
os.mkdir_all(frontend_root) or { panic(err) }
syntax_py := os.join_path(frontend_root, 'syntax.py')
os.write_file(syntax_py, 'def f(:\n    pass\n') or { panic(err) }
for c in [['a syntax error', syntax_py, 'SyntaxError'],
	['a missing file', os.join_path(frontend_root, 'missing.py'), 'does not exist']] {
	res := os.exec([py2v, c[1]])
	name := 'frontend error: ${c[0]}'
	if res.exit_code == 1 && res.output.contains(c[2]) {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, ' (exit ${res.exit_code})')
		println(excerpt_n(res.output, 20))
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
// In a package, a file the frontend cannot translate must not stop the others: the good
// module is written, the bad file is named, and the run still exits 1.
partial_pkg := os.join_path(frontend_root, 'pkg')
partial_out := os.join_path(frontend_root, 'out')
os.mkdir_all(partial_pkg) or { panic(err) }
os.write_file(os.join_path(partial_pkg, '__init__.py'), '') or { panic(err) }
os.write_file(os.join_path(partial_pkg, 'good.py'), 'def g() -> int:\n    return 1\n') or { panic(err) }
os.write_file(os.join_path(partial_pkg, 'bad.py'), 'def f(:\n    pass\n') or { panic(err) }
partial := os.exec([py2v, '--package', partial_pkg, '-o', partial_out])
partial_name := 'package: a file the frontend refuses is skipped'
if partial.exit_code == 1 && os.exists(os.join_path(partial_out, 'py_pkg', 'good.v'))
	&& partial.output.contains('bad.py: ') && partial.output.contains('SyntaxError') {
	report('PASS', partial_name, '')
	passed++
} else {
	report('FAIL', partial_name, ' (exit ${partial.exit_code})')
	println(excerpt_n(partial.output, 20))
	failed++
	failures << fail_line('FAIL', partial_name, '')
}
// A second run in which a file that used to translate is refused must not leave its old
// output behind for `--check` to compile.
os.write_file(os.join_path(partial_pkg, 'bad.py'), 'def old() -> int:\n    return 99\n') or {
	panic(err)
}
stale_out := os.join_path(frontend_root, 'out2')
first_run := os.exec([py2v, '--package', partial_pkg, '-o', stale_out])
os.write_file(os.join_path(partial_pkg, 'bad.py'), 'def f(:\n    pass\n') or { panic(err) }
second_run := os.exec([py2v, '--package', partial_pkg, '-o', stale_out])
stale_name := 'package: the old output of a skipped file is removed'
if first_run.exit_code == 0 && second_run.exit_code == 1
	&& os.exists(os.join_path(stale_out, 'py_pkg', 'good.v'))
	&& !os.exists(os.join_path(stale_out, 'py_pkg', 'bad.v')) {
	report('PASS', stale_name, '')
	passed++
} else {
	report('FAIL', stale_name, ' (exit ${first_run.exit_code}, then ${second_run.exit_code})')
	println(excerpt_n(second_run.output, 20))
	failed++
	failures << fail_line('FAIL', stale_name, '')
}
// A deeply nested file must be translated, not overflow the stack: a chain of 120 `elif`
// branches (Python nests each one in the `else` of the one before) and a sum of 401 terms.
mut elif_src := 'x = 5\nif x == 0:\n    print(0)\n'
for i in 1 .. 120 {
	elif_src += 'elif x == ${i}:\n    print(${i})\n'
}
elif_py := os.join_path(frontend_root, 'elif_chain.py')
os.write_file(elif_py, elif_src) or { panic(err) }
sum_py := os.join_path(frontend_root, 'long_sum.py')
os.write_file(sum_py, 'x = 1' + ' + 1'.repeat(400) + '\nprint(x)\n') or { panic(err) }
for c in [['an elif chain of 120 branches', elif_py, 'x == 119'],
	['a sum of 401 terms', sum_py, '+ 1']] {
	res := os.exec([py2v, c[1]])
	name := 'deep nesting: ${c[0]}'
	if res.exit_code == 0 && res.output.contains(c[2]) {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, ' (exit ${res.exit_code})')
		println(excerpt_n(res.output, 5))
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
os.rmdir_all(frontend_root) or { panic(err) }

println('')
println('----------------------------------------')
println('Summary: ' + passed.str() + ' passed, ' + failed.str() +
	' failed, ' + skipped.str() + ' skipped')
println('Timing: ${suite_watch.elapsed().milliseconds()} ms; execution jobs: ${runtime.nr_jobs()}')

if failures.len > 0 {
	println('')
	println('Failures:')
	for f in failures {
		println('  ' + f)
	}
	exit(1)
}
