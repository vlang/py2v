module main

import os
import sync

// CheckResult records the outcome of compiling one generated V module.
struct CheckResult {
mut:
	module_name string
	error_count int
	first_error string
	first_file  string
}

// check_entry_module is the prefix of the throwaway entry module that forces
// the V compiler to load a generated module. It lives in the project root
// alongside the generated tree for the duration of one check. Concurrent checks
// each need their own entry module, because two files in one directory that
// declare the same module name is an error in V.
const check_entry_module = 'py2v_check_entry'

// v_command returns the V compiler to drive. An explicit V environment
// variable wins so a specific compiler can be exercised. os.getenv yields an
// empty string rather than an Option, so the default is applied here: spawning
// an empty filename would leave the caller waiting on a process that never
// runs.
fn v_command() string {
	override := os.getenv('V')
	if override != '' {
		return override
	}
	return 'v'
}

// CheckDiagnostic is one error diagnostic printed by `v -check`.
struct CheckDiagnostic {
	file    string // empty for a diagnostic without a location
	message string
}

// check_diagnostic returns the error diagnostic that `line` starts, or none.
//
// A located diagnostic is `<file>:<line>:<col>: <label>: <message>` with a
// numeric line and column; the location is read from the right, so a Windows
// path keeps its drive (`C:/x/out.v`). An unlocated one starts with its label.
// The labels that fail a check are `error` and `builder error` (the module
// loader's, for example a missing import); warnings and notices do not. The
// numbered source excerpts V prints below a diagnostic can contain the same
// text, `8 | x := 'a:1:2: error: z'`, and are never diagnostics themselves.
fn check_diagnostic(line string) ?CheckDiagnostic {
	trimmed := line.trim_right('\r').trim_space()
	if is_source_excerpt(trimmed) {
		return none
	}
	for label in ['builder error', 'error'] {
		if trimmed.starts_with('${label}: ') {
			return CheckDiagnostic{
				message: trimmed
			}
		}
		marker := ': ${label}: '
		at := trimmed.index(marker) or { continue }
		location := trimmed[..at]
		col := location.all_after_last(':')
		rest := location.all_before_last(':')
		row := rest.all_after_last(':')
		file := rest.all_before_last(':')
		if !location.contains(':') || !rest.contains(':') || file == '' || !is_number(row)
			|| !is_number(col) {
			continue
		}
		body := trimmed[at + marker.len..].trim_space()
		return CheckDiagnostic{
			file:    file
			message: if label == 'error' { body } else { '${label}: ${body}' }
		}
	}
	return none
}

fn is_number(s string) bool {
	return s != '' && s.bytes().all(it.is_digit())
}

// is_source_excerpt reports a line of the numbered source context V prints
// below a diagnostic: `12 | code`, or `| ~~~` under it.
fn is_source_excerpt(line string) bool {
	if line.starts_with('|') {
		return true
	}
	number, after := line.split_once(' |') or { return false }
	return is_number(number) && (after == '' || after.starts_with(' '))
}

// CheckRun is one `v -check` run: its exit status and its merged output.
struct CheckRun {
	exit_code int
	output    string
}

// run_v_check runs `v -check` over one entry file and returns the exit status
// and the raw compiler output. The output is read to its end before waiting:
// a compiler that writes more than a pipe holds would otherwise block on the
// write while py2v blocks on the wait.
fn run_v_check(work_dir string, entry_rel string) CheckRun {
	mut proc := os.new_process(v_command())
	proc.set_args(['-shared', '-check', '-nocolor', entry_rel])
	proc.set_work_folder(work_dir)
	proc.set_redirect_stdio_merged()
	proc.run()
	output := proc.stdout_slurp()
	proc.wait()
	code := proc.code
	proc.close()
	return CheckRun{
		exit_code: code
		output:    output
	}
}

// check_v_module compiles one generated module and summarises the result.
//
// The check goes through a throwaway entry point that imports the module.
// Checking a generated file directly is not equivalent: V only walks files
// reachable from the file it is given, so a module's own sibling files are
// invisible and every cross-reference between them is reported as an unknown
// function. Because a directory is the unit V actually compiles, one module is
// checked per run, which also gives each module its own diagnostic budget
// instead of sharing the cap across all of its files.
fn check_v_module(work_dir string, module_name string, slot int) CheckResult {
	mut result := CheckResult{
		module_name: module_name
	}
	entry := check_entry_module + '_' + slot.str()
	entry_rel := entry + '.v'
	entry_path := os.join_path(work_dir, entry_rel)
	source := 'module ' + entry + '\n\nimport ' + module_name +
		'\n\npub fn ' + entry + '_unused() {}\n'
	os.write_file(entry_path, source) or {
		result.error_count = 1
		result.first_error = 'could not write check entry: ${err}'
		return result
	}
	defer {
		os.rm(entry_path) or {}
	}
	record_check_run(mut result, run_v_check(work_dir, entry_rel))
	return result
}

// check_v_file compiles one standalone generated file, the output of a
// single-file transpilation. It names the file itself: an importing entry point
// cannot reach a `main` module (no -o) or a module whose directory name is not
// its module name (`-o foo-bar/out.v` holds `module foo_bar`), and checking the
// whole directory would also compile any other .v file that sits beside the
// output. The file has no generated siblings, so nothing is missed.
fn check_v_file(path string) CheckResult {
	mut result := CheckResult{
		module_name: os.base(path)
	}
	record_check_run(mut result, run_v_check(os.dir(path), os.base(path)))
	return result
}

// record_check_run adds one compiler run to `result`: one error per error
// diagnostic it printed (V prints at most 20, then `... and N more errors`, so
// the count is of printed errors). A run that exits non-zero without printing
// any recognised error still counts as one, so a message shape this parser
// does not know can never make a failed module look clean.
fn record_check_run(mut result CheckResult, run CheckRun) {
	for line in run.output.split('\n') {
		diag := check_diagnostic(line) or { continue }
		result.error_count++
		if result.first_error == '' {
			result.first_error = diag.message
			result.first_file = diag.file
		}
	}
	if run.exit_code != 0 && result.error_count == 0 {
		result.error_count = 1
		first := run.output.split('\n').map(it.trim_right('\r').trim_space()).filter(it != '')
		result.first_error = if first.len > 0 {
			'v -check exited with status ${run.exit_code}: ${first[0].limit(200)}'
		} else {
			'v -check exited with status ${run.exit_code} (no diagnostic output)'
		}
	}
}

// check_v_modules compiles every generated module under work_dir, running
// `jobs` compilers concurrently. Each concurrent run owns a distinct entry
// module so they do not collide in the shared project root.
fn check_v_modules(work_dir string, module_names []string, jobs int) []CheckResult {
	if module_names.len == 0 {
		return []
	}
	mut workers := jobs
	if workers < 1 {
		workers = 1
	}
	if workers > module_names.len {
		workers = module_names.len
	}

	tasks := chan int{cap: module_names.len}
	results := chan CheckResult{cap: module_names.len}
	for i in 0 .. module_names.len {
		tasks <- i
	}
	tasks.close()

	mut wg := sync.new_waitgroup()
	// The waitgroup counts tasks, not workers: a worker that drains the queue
	// and finds it closed must not call done(), or wait() would never return.
	wg.add(module_names.len)
	for worker_id in 0 .. workers {
		spawn fn [tasks, results, work_dir, module_names, worker_id, mut wg] () {
			for {
				task := <-tasks or { break }
				value := check_v_module(work_dir, module_names[task], worker_id)
				results <- value
				wg.done()
			}
		}()
	}
	wg.wait()
	results.close()

	mut out := []CheckResult{}
	for {
		result := <-results or { break }
		out << result
	}
	out.sort_with_compare(fn (a &CheckResult, b &CheckResult) int {
		return compare_strings(a.module_name, b.module_name)
	})
	return out
}

// check_report renders the machine readable result table: one
// `module<TAB>errors<TAB>first_error` line per module, sorted by name.
fn check_report(results []CheckResult) string {
	mut lines := []string{}
	for r in results {
		first := r.first_error.replace('\t', ' ').replace('\n', ' ')
		lines << '${r.module_name}\t${r.error_count}\t${first}'
	}
	return lines.join('\n')
}

// check_summary renders the one line human summary printed alongside the table.
fn check_summary(results []CheckResult) string {
	mut broken := 0
	mut total := 0
	mut counts := []int{}
	for r in results {
		total += r.error_count
		if r.error_count > 0 {
			broken++
		}
		counts << r.error_count
	}
	counts.sort()
	median := if counts.len == 0 {
		0
	} else {
		counts[counts.len / 2]
	}
	clean := results.len - broken
	return 'check: ${results.len} modules, ${clean} clean, ${broken} with errors, ' +
		'${total} errors total, median ${median}'
}

// check_worst returns the `n` results with the most errors, most severe first.
// These are the modules worth attacking next: a module with a single error is
// usually a codegen bug, while one with a full diagnostic budget has usually
// already hit the type system.
fn check_worst(results []CheckResult, n int) []CheckResult {
	mut sorted := results.clone()
	sorted.sort_with_compare(fn (a &CheckResult, b &CheckResult) int {
		if a.error_count != b.error_count {
			return b.error_count - a.error_count
		}
		return compare_strings(a.module_name, b.module_name)
	})
	if sorted.len <= n {
		return sorted
	}
	return sorted[..n]
}

// check_module_names lists the generated V modules under root, which are the
// immediate subdirectories that hold a `.v` file, sorted.
fn check_module_names(root string) ![]string {
	mut out := []string{}
	entries := os.ls(root) or { return out }
	for name in entries {
		if name.starts_with('.') || name == check_entry_module {
			continue
		}
		dir := os.join_path(root, name)
		if os.is_dir(dir) && os.ls(dir)!.any(it.ends_with('.v')) {
			out << name
		}
	}
	out.sort()
	return out
}
