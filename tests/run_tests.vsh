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
//   v tests/run_tests.vsh [-lower]
//   -lower removes passing defect exemptions that name no other platform.
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

fn generated_binary(source string) string {
	return source + $if windows { '.exe' } $else { '.bin' }
}

fn build_generated(source string, bin string) os.Result {
	return os.exec([@VEXE, '-path', '@vlib|${project_dir}|@vmodules', '-o', bin, source])
}

// run_generated separates compiler diagnostics from the program's output.
fn run_generated(source string) os.Result {
	bin := generated_binary(source)
	build := build_generated(source, bin)
	if build.exit_code != 0 {
		return build
	}
	return os.exec([bin])
}

// translate_source separates generated source from diagnostic reports on stderr.
fn translate_source(py2v string, source string) os.Result {
	mut process := os.new_process(py2v)
	process.set_args([source])
	process.set_redirect_stdio()
	defer { process.close() }
	process.run()
	diagnostics_thread := spawn process.stderr_slurp()
	output := process.stdout_slurp()
	diagnostics := diagnostics_thread.wait()
	process.wait()
	return os.Result{
		exit_code: process.code
		output:    if process.code == 0 { output } else { output + diagnostics }
	}
}

struct ExecutionResult {
	exit_code      int
	output         string
	compile_failed bool
	reason         string
}

fn first_difference(cpython os.Result, native os.Result) string {
	py_lines := cpython.output.replace('\r', '').split('\n')
	v_lines := native.output.replace('\r', '').split('\n')
	line_count := if py_lines.len > v_lines.len { py_lines.len } else { v_lines.len }
	for i in 0 .. line_count {
		py_line := py_lines[i] or { '<end of output>' }
		v_line := v_lines[i] or { '<end of output>' }
		if py_line != v_line {
			return 'line ${i + 1}: CPython [${py_line}], V [${v_line}]'
		}
	}
	return 'CPython exit ${cpython.exit_code}, V exit ${native.exit_code}'
}

// compare_execution checks observable output against CPython, beyond fixture text.
fn compare_execution(python string, source string, generated string, expected_failure string) ExecutionResult {
	bin := generated_binary(generated)
	build := build_generated(generated, bin)
	if build.exit_code != 0 {
		lines := build.output.split_into_lines()
		mut reason := lines[0] or { 'V compiler exited ${build.exit_code}' }
		for line in lines {
			if line.contains(': error: ') {
				reason = line.all_after(': error: ')
				break
			}
		}
		return ExecutionResult{
			exit_code:      1
			output:         build.output
			compile_failed: true
			reason:         reason
		}
	}
	// UTF-8 mode: on Windows CPython would otherwise use the console code page.
	cpython := os.exec([python, '-X', 'utf8', '-I', source])
	native := os.exec([bin])
	py_output := cpython.output.replace('\r', '')
	v_output := native.output.replace('\r', '')
	if expected_failure != '' {
		// For uncaught exceptions CPython prints a traceback before the class and message.
		if cpython.exit_code == 1 && native.exit_code == 1
			&& py_output.trim_space().split('\n').last() == expected_failure
			&& v_output.trim_space() == expected_failure {
			return ExecutionResult{}
		}
	} else if cpython.exit_code == 0 && native.exit_code == 0 && py_output == v_output {
		return ExecutionResult{}
	}
	return ExecutionResult{
		exit_code: 1
		output:    'CPython (exit ${cpython.exit_code}):\n${cpython.output}\nV (exit ${native.exit_code}):\n${native.output}'
		reason:    first_difference(cpython, native)
	}
}

// check_parser formats and syntax-checks one fixture in its own temporary directory.
fn check_parser(args []string) os.Result {
	translated := os.exec([args[0], args[1]])
	if translated.exit_code != 0 {
		return translated
	}
	os.mkdir_all(os.dir(args[2])) or {
		return os.Result{ exit_code: 1, output: err.msg() }
	}
	os.write_file(args[2], translated.output) or {
		return os.Result{ exit_code: 1, output: err.msg() }
	}
	formatted := os.exec([@VEXE, 'fmt', '-w', args[2]])
	syntax := os.exec([@VEXE, '-check-syntax', args[2]])
	return os.Result{
		exit_code: if formatted.exit_code == 0 && syntax.exit_code == 0 { 0 } else { 1 }
		output:    formatted.output + syntax.output
	}
}

struct ExecutionCase {
	python    string
	source    string
	generated string
}

fn compare_fixture(fixture ExecutionCase) ExecutionResult {
	name := os.file_name(fixture.source).trim_string_right('.py')
	expected_failure := match name {
		'dynamic_method_uncaught_type' {
			'TypeError: sequence item 0: expected str instance, int found'
		}
		'dynamic_method_uncaught_attr' { "AttributeError: 'int' object has no attribute 'append'" }
		'empty_set_uncaught' { "AttributeError: 'set' object has no attribute 'append'" }
		'sys_exit' { 'OK' }
		else { '' }
	}
	return compare_execution(fixture.python, fixture.source, fixture.generated, expected_failure)
}

struct ExecutionExemption {
	kind      string
	reason    string
	platforms []string
}

const exemption_classes = ['needs-input', 'needs-dependency', 'nondeterministic', 'does-not-compile',
	'differs', 'python-version', 'needs-sqlite']!
const exemption_platforms = ['macos', 'linux', 'windows']!

fn (exemption ExecutionExemption) for_platform(platform string) ExecutionExemption {
	if exemption.platforms.len == 0 || platform in exemption.platforms {
		return exemption
	}
	return ExecutionExemption{}
}

fn read_execution_exemptions(lines []string, files []string) !map[string]ExecutionExemption {
	mut exemptions := map[string]ExecutionExemption{}
	for i, line in lines {
		if line == '' || line.starts_with('#') {
			continue
		}
		parts := line.split('\t')
		if parts.len !in [3, 4] || parts[1] !in exemption_classes || parts[2].trim_space() == '' {
			return error('execution_exempt.tsv:${i + 1}: expected case<TAB>class<TAB>reason[<TAB>platforms]')
		}
		mut platforms := []string{}
		if parts.len == 4 && parts[3] != '' {
			for platform in parts[3].split(',') {
				if platform !in exemption_platforms || platform in platforms {
					return error('execution_exempt.tsv:${i + 1}: invalid or duplicate platform "${platform}"')
				}
				platforms << platform
			}
		}
		name := parts[0]
		if name + '.py' !in files {
			return error('execution_exempt.tsv:${i + 1}: no such case: ${name}')
		}
		if name in exemptions {
			return error('execution_exempt.tsv:${i + 1}: duplicate case: ${name}')
		}
		exemptions[name] = ExecutionExemption{parts[1], parts[2], platforms}
	}
	return exemptions
}

fn compare_fixtures(fixtures []ExecutionCase, root string) ![]ExecutionResult {
	// File-writing fixtures run with a scratch working directory and TMPDIR.
	work := os.join_path(root, 'work')
	os.mkdir(work)!
	previous_dir := os.getwd()
	previous_tmp := os.getenv_opt('TMPDIR')
	os.chdir(work)!
	os.setenv('TMPDIR', work, true)
	defer {
		os.chdir(previous_dir) or { panic(err) }
		if value := previous_tmp {
			os.setenv('TMPDIR', value, true)
		} else {
			os.unsetenv('TMPDIR')
		}
	}
	return parallel.amap(fixtures, compare_fixture, workers: runtime.nr_jobs())
}

const script_dir = os.dir(os.abs_path(@FILE))
const project_dir = os.dir(script_dir)
const cases_dir = os.join_path(script_dir, 'cases')
const expected_dir = os.join_path(script_dir, 'expected')
const package_fixtures = ['pkg_imports', 'pkg_lib_main', 'pkg_multi', 'pkg_multi2', 'pkg_true_div',
	'pkg_init_execution', 'pkg_private_names', 'pkg_call_defaults', 'pkg_type_only',
	'pkg_qualified_construct', 'pkg_colliding_functions', 'pkg_annotated_constants',
	'pkg_class_constant_alias', 'pkg_module_string_product', 'pkg_guard_class', 'pkg_class_owners',
	'pkg_import_branch', 'pkg_runtime_binding', 'pkg_map_items_globals']!

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

case_files := os.ls(cases_dir) or { panic(err) }
mut case_names := case_files.filter(it.ends_with('.py') && os.is_file(os.join_path(cases_dir, it)))
case_names.sort()

mut passed := 0
mut failed := 0
mut skipped := 0
mut failures := []string{}
mut verbose := os.getenv('VERBOSE') == '1'
mut fmt_seq := 0
python := $if windows { 'python' } $else { 'python3' }
platform := os.user_os()
exemption_path := os.join_path(script_dir, 'execution_exempt.tsv')
exemption_lines := os.read_lines(exemption_path) or { panic(err) }
exemptions := read_execution_exemptions(exemption_lines, case_names) or {
	eprintln(err.msg())
	exit(1)
}
lower := '-lower' in os.args
execution_root := os.join_path(os.temp_dir(), 'py2v_execution_${os.getpid()}')
os.mkdir(execution_root, mode: 0o700) or { panic(err) }
mut fixtures := []ExecutionCase{}
mut exemption_counts := map[string]int{}

for entry in case_names {
	case_name := entry.trim_string_right('.py')
	expected_file := os.join_path(expected_dir, case_name + '.v')
	case_path := os.join_path(cases_dir, entry)

	exemption := exemptions[case_name].for_platform(platform)
	if exemption.kind == 'python-version' {
		// Parse the marked source without importing it or writing bytecode.
		syntax := os.exec([python, '-X', 'utf8', '-I', '-c',
			'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_bytes())', case_path])
		if syntax.exit_code != 0 {
			if syntax.output.contains('\nSyntaxError:') {
				report('SKIP', case_name, ' (${exemption.reason})')
				skipped++
				exemption_counts[exemption.kind]++
			} else {
				report('FAIL', case_name, ' (CPython syntax probe failed)')
				println(syntax.output)
				failed++
				failures << fail_line('FAIL', case_name, ' (CPython syntax probe failed)')
			}
			continue
		}
	}

	res := translate_source(py2v, case_path)
	if res.exit_code != 0 {
		report('FAIL', case_name, ' (transpilation error)')
		failed++
		failures << fail_line('FAIL', case_name, ' (transpilation error)')
		continue
	}

	generated_path := os.join_path(execution_root, case_name + '.v')
	os.write_file(generated_path, res.output) or { panic(err) }
	if exemption.kind in ['', 'python-version', 'needs-sqlite', 'does-not-compile', 'differs'] {
		fixtures << ExecutionCase{python, case_path, generated_path}
	} else {
		report('SKIP', 'runtime execution: ' + case_name, ' (${exemption.kind}: ${exemption.reason})')
		skipped++
		exemption_counts[exemption.kind]++
	}
	if !os.exists(expected_file) {
		report('SKIP', case_name, ' (no expected file)')
		skipped++
		continue
	}
	expected := os.read_file(expected_file) or { panic(err) }
	mut generated := res.output
	mut expected_norm := expected
	if generated != expected_norm {
		fmt_seq++
		generated = normalize_v_code(generated, fmt_seq)
		fmt_seq++
		expected_norm = normalize_v_code(expected_norm, fmt_seq)
	}

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

execution_results := compare_fixtures(fixtures, execution_root) or { panic(err) }
mut compared := 0
mut obsolete_exemptions := []string{}
for i, result in execution_results {
	case_name := os.file_name(fixtures[i].source).trim_string_right('.py')
	name := 'runtime execution: ' + case_name
	exemption := exemptions[case_name].for_platform(platform)
	if exemption.kind in ['does-not-compile', 'differs'] {
		if result.exit_code == 0 {
			if lower && exemption.platforms.len <= 1 {
				obsolete_exemptions << case_name
			} else {
				guidance := if exemption.platforms.len > 1 {
					'review on ${exemption.platforms.join(', ')} before editing this row'
				} else {
					'run `v tests/run_tests.vsh -lower`'
				}
				detail := ' (exemption now passes on ${platform}, ${guidance})'
				report('FAIL', name, detail)
				failures << fail_line('FAIL', name, detail)
				failed++
				exemption_counts[exemption.kind]++
				continue
			}
		} else {
			report('SKIP', name, ' (${exemption.kind}: ${exemption.reason})')
			skipped++
			exemption_counts[exemption.kind]++
			continue
		}
	}
	if exemption.kind == 'needs-sqlite' && result.compile_failed
		&& result.output.contains('thirdparty/sqlite') {
		report('SKIP', name, ' (${exemption.reason})')
		skipped++
		exemption_counts[exemption.kind]++
		continue
	}
	compared++
	if result.exit_code == 0 {
		report('PASS', name, '')
		passed++
	} else {
		kind := if result.compile_failed { 'does-not-compile' } else { 'differs' }
		detail := ' (${kind}: ${result.reason})'
		report('FAIL', name, detail)
		println(result.output)
		failed++
		failures << fail_line('FAIL', name, detail)
	}
}

dynamic_root := os.join_path(os.temp_dir(), 'py2v_dynamic_${os.getpid()}')
os.mkdir_all(dynamic_root) or { panic(err) }
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

// Exercise the paths that require a dependency or scheduler on purpose.
for control in [
	['external_dynamic', 'println(from_context(', 'lookup()', 'ImportError: untranslated Python import'],
	['scheduling_refusal', 'println(supported())', 'read_future(0)',
		'V panic: py2v_unsupported_coroutine'],
] {
	case_name := control[0]
	source := os.read_file(os.join_path(execution_root, case_name + '.v')) or { panic(err) }
	mut lines := source.split_into_lines()
	for index, line in lines {
		if line.trim_space().starts_with(control[1]) {
			lines[index] = '\t' + control[2]
		}
	}
	driver := os.join_path(execution_root, case_name + '_failure.v')
	os.write_file(driver, lines.join('\n') + '\n') or { panic(err) }
	result := run_generated(driver)
	name := '${case_name} fails loudly'
	if result.exit_code != 0 && result.output.contains(control[3]) {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println(result.output)
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
// Calling the isolated refusal must fail while its unrelated neighbor still runs.
scoped_source := os.join_path(execution_root, 'list_scoped_refusal.v')
scoped_code := os.read_file(scoped_source) or { panic(err) }
scoped_refused := os.join_path(execution_root, 'list_scoped_refused.v')
scoped_targets := ['refused', 'refused_groups', 'refused_lambda_callback', 'refused_caller',
	'refused_default', 'refused_received']
mut scoped_dispatch := []string{}
for target in scoped_targets {
	scoped_dispatch << "\tif os.args[1] == '${target}' {\n\t\t${target}()\n\t\treturn\n\t}"
}
scoped_dispatch << "\tpanic('unknown refusal target')"
driver_code := scoped_code.replace('module main\n', 'module main\n\nimport os\n')
	.replace('\tunrelated()\n', scoped_dispatch.join('\n') + '\n')
os.write_file(scoped_refused, driver_code) or {
	panic(err)
}
scoped_binary := scoped_refused + $if windows { '.exe' } $else { '.bin' }
scoped_build := os.exec([@VEXE, '-path', '@vlib|${project_dir}|@vmodules', '-o', scoped_binary,
	scoped_refused])
mut scoped_runs := [][]string{}
for target in scoped_targets { scoped_runs << [scoped_binary, target] }
scoped_results := parallel.amap(scoped_runs, os.exec, workers: runtime.nr_jobs())
for i, scoped_run in scoped_results {
	name := 'list identity: ${scoped_targets[i]} fails loudly'
	if scoped_build.exit_code == 0 && scoped_run.exit_code != 0
		&& scoped_run.output.contains('V panic: py2v_unsupported_list_identity') {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println(scoped_build.output + scoped_run.output)
		failed++
		failures << fail_line('FAIL', name, '')
	}
}

// An unprovable module-level list also blocks an importing package explicitly.
scoped_package := os.join_path(execution_root, 'scope_pkg')
scoped_output := os.join_path(execution_root, 'scope_out')
os.mkdir_all(scoped_package) or { panic(err) }
os.mkdir_all(scoped_output) or { panic(err) }
os.write_file(os.join_path(scoped_package, '__init__.py'), os.read_file(os.join_path(cases_dir,
	'list_scoped_escape_refusal.py')) or { panic(err) }) or { panic(err) }
scoped_package_translation := os.exec([py2v, '--package', scoped_package, '-o', scoped_output])
scoped_entry := os.join_path(scoped_output, 'main.v')
os.write_file(scoped_entry, 'module main\nimport py_scope_pkg\nfn main() { py_scope_pkg.unrelated() }\n') or {
	panic(err)
}
scoped_import := run_generated(scoped_entry)
if scoped_package_translation.exit_code == 0 && scoped_import.exit_code != 0
	&& scoped_import.output.contains('py2v_unsupported_list_identity_module')
	&& scoped_package_translation.output.contains('module-level list refusal') {
	report('PASS', 'list identity: module-level package refusal', '')
	passed++
} else {
	report('FAIL', 'list identity: module-level package refusal', '')
	println(scoped_package_translation.output + scoped_import.output)
	failed++
	failures << fail_line('FAIL', 'list identity: module-level package refusal', '')
}
// Refused identity operations must fail loudly with an explicit boundary diagnostic.
for refusal in [
	['list_identity_refusal', '[1, 2, 3]', 'during iteration'],
	['list_iteration_call_refusal', '[1, 2, 3]', 'during iteration'],
	['list_iteration_aug_refusal', '[1, 2, 3]', 'during iteration'],
	['list_iteration_slice_refusal', '[4, 5, 6] [1, 5, 6]', 'during iteration'],
	['list_comprehension_refusal', '[1, 2, 3]', 'during iteration'],
	['list_enumerate_refusal', '[1, 2, 3] [1, 2, 3]', 'during iteration'],
	['list_call_refusal', '[1, 2]', 'unresolved call'],
	['list_scoped_escape_refusal', '42', 'ordering comparison'],
] {
	refusal_source := os.join_path(cases_dir, refusal[0] + '.py')
	refusal_translation := translate_source(py2v, refusal_source)
	refusal_v := os.join_path(execution_root, refusal[0] + '.v')
	os.write_file(refusal_v, refusal_translation.output) or { panic(err) }
	refusal_run := run_generated(refusal_v)
	refusal_python := os.exec([python, '-X', 'utf8', '-I', refusal_source])
	name := 'list identity: ${refusal[0]} refusal'
	if refusal_translation.exit_code == 0 && refusal_python.exit_code == 0
		&& refusal_python.output.trim_space() == refusal[1]
		&& refusal_translation.output.contains(refusal[2])
		&& refusal_run.exit_code != 0 && refusal_run.output.contains('py2v_unsupported_list_identity') {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println(refusal_run.output)
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
for refusal in [
	['list_box_range_refusal', '[1, 1099511627776]', 'py2v: runtime integer does not fit'],
] {
	refusal_source := os.join_path(cases_dir, refusal[0] + '.py')
	refusal_translation := os.exec([py2v, refusal_source])
	refusal_v := os.join_path(execution_root, refusal[0] + '.v')
	os.write_file(refusal_v, refusal_translation.output) or { panic(err) }
	refusal_run := run_generated(refusal_v)
	refusal_python := os.exec([python, '-X', 'utf8', '-I', refusal_source])
	name := 'list identity: ${refusal[0]} refusal'
	if refusal_translation.exit_code == 0 && refusal_python.exit_code == 0
		&& refusal_python.output.trim_space() == refusal[1]
		&& refusal_run.exit_code != 0 && refusal_run.output.contains(refusal[2]) {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println(refusal_run.output)
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
os.rmdir_all(execution_root) or { panic(err) }

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
		if pkg == 'pkg_qualified_construct' {
			for part in ['defs', 'use'] {
				actual := os.read_file(os.join_path(out_dir, 'py_${part}', '__init__.v')) or { panic(err) }
				expected := os.read_file(os.join_path(expected_dir, pkg, part, '__init__.v')) or { panic(err) }
				name := 'qualified constructor: ${part} fixture'
				if actual.replace('\r', '') == expected.replace('\r', '') {
					report('PASS', name, '')
					passed++
				} else {
					report('FAIL', name, '')
					failed++
					failures << fail_line('FAIL', name, '')
				}
			}
			entry := os.join_path(out_dir, 'qualified_main.v')
			os.write_file(entry, 'module main\nimport py_use\nfn main() {\n\tprintln(py_use.total())\n}\n') or { panic(err) }
			driver := os.join_path(out_dir, 'driver.py')
			os.write_file(os.join_path(out_dir, 'source_path.txt'), cases_dir) or { panic(err) }
			os.write_file(driver, 'import sys\nfrom pathlib import Path\nsys.path.insert(0, Path(__file__).with_name("source_path.txt").read_text(encoding="utf-8"))\nfrom pkg_qualified_construct.use import total\nprint(total())\n') or { panic(err) }
			result := compare_execution(python, driver, entry, '')
			name := 'qualified constructor: package execution'
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
		if pkg in ['pkg_type_only', 'pkg_colliding_functions', 'pkg_annotated_constants',
			'pkg_class_constant_alias', 'pkg_module_string_product', 'pkg_guard_class',
			'pkg_class_owners', 'pkg_import_branch', 'pkg_runtime_binding', 'pkg_map_items_globals'] {
			fixtures := match pkg {
				'pkg_type_only' {
					['acyclic/consumer', 'cycle_b/consumer', 'model/holder', 'model/frozen']
				}
				'pkg_colliding_functions' { ['__init__', 'left', 'right'] }
				'pkg_guard_class' { ['__init__', 'choice', 'demo', 'public'] }
				'pkg_class_owners' { ['__init__', 'consumer', 'left', 'owner_check', 'right'] }
				'pkg_import_branch' { ['__init__', 'available', 'choice'] }
				'pkg_runtime_binding' { ['__init__', 'choice'] }
				else { ['__init__'] }
			}
			for fixture in fixtures {
				subpackage := if fixture.contains('/') {
					'_' + fixture.all_before_last('/')
				} else {
					''
				}
				module_name := 'py_${pkg}${subpackage}'
				stem := if fixture.contains('/') { fixture.all_after_last('/') } else { fixture }
				actual := os.read_file(os.join_path(out_dir, module_name, '${stem}.v')) or { '' }
				expected := os.read_file(os.join_path(expected_dir, pkg, fixture + '.v')) or { '' }
				name := '${pkg}: fixture ${fixture}'
				if actual.len > 0 && expected.len > 0 && actual.replace('\r', '') == expected.replace('\r', '') {
					report('PASS', name, '')
					passed++
				} else {
					report('FAIL', name, '')
					failed++
					failures << fail_line('FAIL', name, '')
				}
			}
			python_root := os.join_path(out_dir, 'python')
			for source in os.walk_ext(pkg_dir, '.py') {
				relative := source[pkg_dir.len..].trim_left('/\\')
				destination := os.join_path(python_root, pkg, relative)
				os.mkdir_all(os.dir(destination)) or { panic(err) }
				os.cp(source, destination) or { panic(err) }
			}
			driver := os.join_path(python_root, 'driver.py')
			python_module := if pkg == 'pkg_type_only' { '${pkg}.main' } else { pkg }
			python_extra := match pkg {
				'pkg_guard_class' {
					'import runpy\nrunpy.run_module("${pkg}.demo", run_name="__main__")\n'
				}
				'pkg_class_owners' {
					'from ${pkg}.owner_check import sibling_result\nprint(sibling_result())\n'
				}
				else { '' }
			}
			os.write_file(driver, 'import sys\nfrom pathlib import Path\nsys.path.insert(0, str(Path(__file__).parent))\nfrom ${python_module} import total\nprint(total())\n${python_extra}') or { panic(err) }
			entry := os.join_path(out_dir, 'fixture_main.v')
			v_extra := match pkg {
				'pkg_guard_class' { '\tpy_${pkg}.demo_main()\n' }
				'pkg_class_owners' { '\tprintln(py_${pkg}.sibling_result())\n' }
				else { '' }
			}
			os.write_file(entry, 'module main\n\nimport py_${pkg}\n\nfn main() {\n\tprintln(py_${pkg}.total())\n${v_extra}}\n') or { panic(err) }
			result := compare_execution(python, driver, entry, '')
			name := '${pkg}: execution'
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
		if pkg == 'pkg_call_defaults' {
			for stem in ['use', 'keywords', 'float_defaults', 'local_defaults', 'keyword_only',
				'style_keywords'] {
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
			style_entry := os.join_path(out_dir, 'style_main.v')
			driver := os.join_path(out_dir, 'style_driver.py')
			os.write_file(style_entry, 'module main\n\nimport py_pkg_call_defaults_consumer\n\nfn main() {\n\tpy_pkg_call_defaults_consumer.run_style_keywords()\n}\n') or { panic(err) }
			os.write_file(os.join_path(out_dir, 'source_path.txt'), cases_dir) or { panic(err) }
			// The external mypyc decorator returns its input unchanged on CPython.
			os.write_file(driver, 'import sys\nfrom pathlib import Path\nfrom types import ModuleType\nmetadata = ModuleType("mypy_extensions")\nmetadata.mypyc_attr = lambda **kwargs: lambda fn: fn\nsys.modules["mypy_extensions"] = metadata\nsys.path.insert(0, Path(__file__).with_name("source_path.txt").read_text(encoding="utf-8"))\nfrom pkg_call_defaults.consumer.style_keywords import run_style_keywords\nrun_style_keywords()\n') or { panic(err) }
			style_result := compare_execution(python, driver, style_entry, '')
			style_name := 'call defaults: package keyword map execution'
			if style_result.exit_code == 0 {
				report('PASS', style_name, '')
				passed++
			} else {
				report('FAIL', style_name, '')
				println(style_result.output)
				failed++
				failures << fail_line('FAIL', style_name, '')
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

// An external constructor resolves through the runtime when its package is absent.
external_out := os.join_path(os.temp_dir(), 'py2v_init_external_${os.getpid()}')
external := os.exec([py2v, '--package', os.join_path(cases_dir, 'pkg_init_external'), '-o',
	external_out])
external_code := os.read_file(os.join_path(external_out, 'py_pkg_init_external', 'use.v')) or {
	''
}
external_expected := os.read_file(os.join_path(script_dir, 'baseline', 'pkg_init_external.v.txt')) or {
	panic(err)
}
external_name := 'initializers: unavailable external class resolves at runtime'
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

// An unsupported native representation leaves its site visible to the checker.
// CPython still runs these witnesses to establish the missing behavior.
refusal_root := os.join_path(os.temp_dir(), 'py2v_refusals_${os.getpid()}')
os.mkdir_all(refusal_root) or { panic(err) }
refusal_v := os.join_path(refusal_root, 'main.v')
for witness in [
	['review_alias',
		'9223372036854775808\n18446744073709551616\n-1\n18446744073709551616\n36893488147419103232',
		'wide integer'],
	['review_constant', '18446744073709551616', 'wide integer'],
	['wide_literal', '18446744073709551617', 'wide integer'],
	['review_annotations', 'xy\nxy\n4\nseq-type\nnone\nseq-type', 'annotated call'],
	['wide_add', '18446744073709551616', 'wide integer'],
	['wide_multiply', '36893488147419103232', 'wide integer'],
	['wide_subtract', '-9223372036854775807', 'wide integer'],
	['wide_negate', '-9223372036854775808', 'wide integer'],
	['wide_mixed', '9223372036854775807', 'wide integer'],
	['wide_shift', '18446744073709551616', 'wide integer'],
	['wide_hidden_overflow', '9223372036854775808', 'wide integer'],
	['wide_sum', '18446744073709551616', 'wide integer'],
	['wide_float_compare', 'False', 'wide integer'],
	['wide_index', 'IndexError', 'wide integer'],
	['wide_range', '0', 'wide integer'],
	['wide_key', 'zero high', 'wide integer'],
	['wide_call', '9223372036854775808', 'wide integer'],
	['wide_divmod', '(1317624576693539401, 1)', 'wide integer'],
	['wide_any_argument', '9223372036854775808', 'wide integer'],
	['wide_any_return', '9223372036854775808', 'wide integer'],
	['wide_any_list_argument', '9223372036854775808', 'wide integer'],
	['wide_any_callback', '9223372036854775808', 'wide integer'],
	['wide_any_list_read', '9223372036854775808', 'wide integer'],
	['wide_any_list_mutation', '9223372036854775808\n-1', 'wide integer'],
	['wide_native_list_append_negative', '9223372036854775808\n-1', 'wide integer'],
	['wide_big_comparison', 'True', 'wide integer'],
	['wide_big_mask', '3', 'wide integer'],
	['wide_compare_overflow', 'True', 'wide integer'],
	['wide_alias_field', '0\n18446744073709551615', 'wide integer'],
	['wide_class_default', '9223372036854775808', 'wide integer'],
	['wide_class_default_mask', '0', 'wide integer'],
	['wide_percent_derived_precision', '92233', 'wide integer'],
	['wide_percent_derived_width', '      9223372036854775808', 'wide integer'],
	['wide_bit_callable', '64\n64\n0\n0', 'wide integer'],
	['wide_sink_abs', '9223372036854775808', 'wide integer'],
	['wide_sink_bool', 'True', 'wide integer'],
	['wide_sink_callback_result', '0o1000000000000000000000', 'wide integer'],
	['wide_sink_dict', '1', 'wide integer'],
	['wide_sink_field', '0o1000000000000000000000', 'wide integer'],
	['wide_sink_field_write', '-1', 'wide integer'],
	['wide_sink_float', '9.223372036854776e+18', 'wide integer'],
	['wide_sink_format', '9223372036854775808.0', 'wide integer'],
	['wide_sink_hash', '4', 'wide integer'],
	['wide_sink_index', 'a', 'wide integer'],
	['wide_sink_int', '9223372036854775808', 'wide integer'],
	['wide_sink_list', '9223372036854775808', 'wide integer'],
	['wide_sink_loop_target', '-1\n-1', 'wide integer'],
	['wide_sink_max', '9223372036854775808', 'wide integer'],
	['wide_sink_membership', 'False', 'wide integer'],
	['wide_sink_method', '8000000000000000', 'wide integer'],
	['wide_sink_method_result', '0o1000000000000000000000', 'wide integer'],
	['wide_sink_min', '0', 'wide integer'],
	['wide_sink_oct', '0o1000000000000000000000', 'wide integer'],
	['wide_sink_pickle', '9223372036854775808', 'wide integer'],
	['wide_sink_set', '1', 'wide integer'],
	['wide_sink_slice', 'abc', 'wide integer'],
	['wide_sink_sort', '[2, 1]', 'wide integer'],
	['wide_sink_truth', 'taken', 'wide integer'],
	['wide_sink_tuple', '9223372036854775808', 'wide integer'],
	['wide_sink_unpack', '-1 1', 'wide integer'],
	['unicode_lone_surrogate', '1', 'unicode surrogate'],
	['unicode_pair_surrogates', '2', 'unicode surrogate'],
] {
	source := os.join_path(cases_dir, 'review_refusals', witness[0] + '.py')
	oracle := os.exec([python, '-X', 'utf8', '-I', source])
	translated := translate_source(py2v, source)
	name := 'checker refusal: ' + witness[0]
	symbol := 'py2v_unsupported_' + witness[2].replace(' ', '_')
	checked := if translated.exit_code == 0 {
		os.write_file(refusal_v, translated.output) or { panic(err) }
		os.exec([@VEXE, '-path', '@vlib|${project_dir}|@vmodules', '-check', refusal_v])
	} else {
		translated
	}
	if oracle.exit_code == 0 && oracle.output.replace('\r', '').trim_right('\n') == witness[1]
		&& translated.exit_code == 0 && translated.output.contains(symbol + '(')
		&& checked.exit_code != 0 && checked.output.contains('error: unknown function: ${symbol}') {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println(oracle.output)
		println(excerpt_n(checked.output, 20))
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
refusal_pkg := os.join_path(refusal_root, 'pkg')
refusal_out := os.join_path(refusal_root, 'out')
os.mkdir_all(refusal_pkg) or { panic(err) }
os.cp(os.join_path(cases_dir, 'review_refusals', 'wide_literal.py'),
	os.join_path(refusal_pkg, '__init__.py')) or { panic(err) }
refusal_package := os.exec([py2v, '--package', refusal_pkg, '-o', refusal_out, '--check'])
refusal_package_code := os.read_file(os.join_path(refusal_out, 'py_pkg', '__init__.v')) or { '' }
refusal_package_name := 'checker refusal: unsupported package-level statement'
if refusal_package.exit_code == 1 && refusal_package_code.contains('pub fn preserved(')
	&& refusal_package.output.contains('unknown function: py2v_unsupported_wide_integer') {
	report('PASS', refusal_package_name, '')
	passed++
} else {
	report('FAIL', refusal_package_name, '')
	println(excerpt_n(refusal_package.output, 20))
	failed++
	failures << fail_line('FAIL', refusal_package_name, '')
}
os.rmdir_all(refusal_root) or { panic(err) }

word_package := os.join_path(cases_dir, 'review_refusals', 'word_package')
word_package_output := os.join_path(os.temp_dir(), 'py2v_word_package_${os.getpid()}')
word_package_oracle := os.exec([python, '-B', '-E', '-s', os.join_path(word_package, '__init__.py')])
word_package_check := os.exec([py2v, '--package', word_package, '-o', word_package_output, '--check'])
word_package_v := os.read_file(os.join_path(word_package_output, 'py_word_package',
	'__init__.v')) or { '' }
word_package_refusal := 'checker refusal: imported unsigned values and results'
if word_package_oracle.exit_code == 0
	&& word_package_oracle.output.replace('\r', '').trim_right('\n') == '0o1000000000000000000000\n'.repeat(4).trim_right('\n')
	&& word_package_check.exit_code == 1
	&& word_package_v.count('py2v_unsupported_wide_integer(') == 4
	&& word_package_check.output.contains('unknown function: py2v_unsupported_wide_integer') {
	report('PASS', word_package_refusal, '')
	passed++
} else {
	report('FAIL', word_package_refusal, '')
	println(word_package_oracle.output)
	println(excerpt_n(word_package_check.output, 20))
	failed++
	failures << fail_line('FAIL', word_package_refusal, '')
}
os.rmdir_all(word_package_output) or { panic(err) }

// Parser regressions must survive V's formatter and syntax checker. Execute the
// supported lowerings too: a parseable closure can still capture the wrong state.
// These are repository-authored fixtures, never third-party corpus programs.
parser_root := os.join_path(os.temp_dir(), 'py2v_parser_${os.getpid()}')
os.mkdir_all(parser_root) or { panic(err) }
execution_cases := ['bound_append', 'closure_capture_discriminator', 'conditional_condition',
	'conditional_map', 'custom_remove', 'divmod_value', 'empty_isinstance', 'expression_walrus',
	'independent_dunders', 'local_identifier_encoding', 'loop_scope_bindings', 'loop_unpack_targets',
	'nested_closures', 'overload_definitions', 'parameter_bindings', 'private_method_calls',
	'nonlocal_closure', 'nested_functions', 'closure_uses_class', 'review_nested_default',
	'review_nested_default_snapshot', 'review_nested_default_once', 'review_nested_if',
	'review_nested_loop', 'review_nested_literal_block', 'review_divmod_negative_float']
syntax_cases := ['annotation_syntax', 'bound_append_rebound', 'dynamic_isinstance',
	'dynamic_isinstance_bindings', 'dynamic_slice_axes', 'generator_value_context',
	'independent_dunder_chain', 'qualified_constant_conditions', 'unresolved_qualified_call',
	'unsupported_closure_capture', 'unsupported_expression_walrus', 'unsupported_format_fields',
	'unsupported_super_value']
mut parser_cases := execution_cases.clone()
parser_cases << syntax_cases
mut parser_args := [][]string{}
for case_name in parser_cases {
	parser_args << [py2v, os.join_path(cases_dir, case_name + '.py'),
		os.join_path(parser_root, case_name, 'main.v')]
}
parser_results := parallel.amap(parser_args, check_parser, workers: runtime.nr_jobs())
for i, result in parser_results {
	name := 'parser regression: ' + parser_cases[i]
	if result.exit_code == 0 {
		report('PASS', name, '')
		passed++
	} else {
		report('FAIL', name, '')
		println(excerpt_n(result.output, 25))
		failed++
		failures << fail_line('FAIL', name, '')
	}
}
os.rmdir_all(parser_root) or { panic(err) }

if lower && obsolete_exemptions.len > 0 && failed == 0 {
	if (os.read_lines(exemption_path) or { panic(err) }) != exemption_lines {
		eprintln('execution_exempt.tsv changed during the suite. Rerun -lower.')
		exit(1)
	}
	mut retained := []string{}
	for line in exemption_lines {
		if line.all_before('\t') !in obsolete_exemptions {
			retained << line
		}
	}
	os.write_file(exemption_path, retained.join('\n') + '\n') or { panic(err) }
	println('removed ${obsolete_exemptions.len} passing execution exemptions')
}
mut exempt := 0
mut by_class := []string{}
for kind in exemption_classes {
	if count := exemption_counts[kind] {
		exempt += count
		by_class << '${count} ${kind}'
	}
}
class_detail := if by_class.len > 0 { by_class.join(', ') } else { 'none' }
println('')
println('----------------------------------------')
println('execution: ${compared} of ${case_names.len} cases compared with CPython, ${exempt} exempt (${class_detail})')
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
