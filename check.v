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

// check_diagnostic returns the compiler diagnostic carried by `line`, or an
// empty string when `line` is not one.
//
// `v -check` interleaves diagnostics with numbered source excerpts, so a
// diagnostic is identified by its own `error:` marker rather than by the mere
// presence of the word error. Three shapes occur, and all three have to be
// recognised: a located `file:line:col: error: ...`, a whole-run `error: ...`
// with no location, and a `builder error: ...` from the module loader.
fn check_diagnostic(line string) string {
	trimmed := line.trim_space()
	if trimmed.starts_with('error: ') || trimmed.starts_with('builder error:') {
		return trimmed
	}
	_, tail := trimmed.split_once(': error: ') or { return '' }
	return tail.trim_space()
}

// check_error_source returns the `path:line:col:` prefix of a diagnostic, or an
// empty string for a `builder error:` that names no source location.
fn check_error_source(line string) string {
	trimmed := line.trim_space()
	head, _ := trimmed.split_once(': error: ') or { return '' }
	return head
}

// run_v_check runs `v -check` over one entry file and returns the raw compiler
// output.
fn run_v_check(work_dir string, entry_rel string) string {
	mut proc := os.new_process(v_command())
	proc.set_args(['-shared', '-check', entry_rel])
	proc.set_work_folder(work_dir)
	proc.set_redirect_stdio_merged()
	proc.run()
	proc.wait()
	return proc.stdout_slurp()
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
	for line in run_v_check(work_dir, entry_rel).split('\n') {
		diag := check_diagnostic(line)
		if diag == '' {
			continue
		}
		result.error_count++
		if result.first_error == '' {
			result.first_error = diag
			result.first_file = check_error_source(line).all_before(':')
		}
	}
	return result
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
fn check_module_names(root string) []string {
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
