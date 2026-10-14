#!/usr/bin/env -S v

import os

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

const script_dir = os.dir(os.abs_path(@FILE))
const project_dir = os.dir(script_dir)
const cases_dir = os.join_path(script_dir, 'cases')
const expected_dir = os.join_path(script_dir, 'expected')
const package_fixtures = ['pkg_imports', 'pkg_multi', 'pkg_multi2']

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
	}
	os.rmdir_all(out_dir) or { panic(err) }
}

println('')
println('----------------------------------------')
println('Summary: ' + passed.str() + ' passed, ' + failed.str() +
	' failed, ' + skipped.str() + ' skipped')

if failures.len > 0 {
	println('')
	println('Failures:')
	for f in failures {
		println('  ' + f)
	}
	exit(1)
}
