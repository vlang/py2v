#!/usr/bin/env -S v

import strconv
import os

// Corpus harness: translate a whole Python tree, compile every generated
// module, and track the result against a checked-in baseline.
//
// This exists because transpiling a large codebase fails in a way a fixture
// test cannot see. Each module either compiles or it does not, and the useful
// signal is the distribution of failures across the corpus, not any single
// output. The baseline turns "there are a lot of errors" into a number that
// must not grow.
//
// Invoke it with:
//
//   v tests/corpus.vsh <package-root> [options]
//
// Options:
//   -o <dir>        Where to write the generated tree (default: a temp dir)
//   --baseline <f>  Compare against this baseline file (default: tests/baseline/<name>.txt)
//   --update        Write the current results to the baseline and exit
//   --jobs <n>      Compilers to run in parallel (default: PY2V_JOBS or 8)
//   --top <n>       How many of the worst modules to list (default: 20)
//   --keep          Keep the generated tree instead of deleting it
//
// Environment:
//   PY2V=<path>  use an explicit py2v binary instead of the one beside this script
//   PY2V_JOBS=<n>  default parallelism for --check

const script_dir = os.dir(os.abs_path(@FILE))
const project_dir = os.dir(script_dir)

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

// read_baseline loads a `module<TAB>errors` baseline, returning an empty map
// when the file does not exist yet. Rows are keyed by generated V module, which
// is the unit V actually compiles.
fn read_baseline(path string) map[string]int {
	mut out := map[string]int{}
	content := os.read_file(path) or { return out }
	for line in content.split('\n') {
		if line.trim_space() == '' {
			continue
		}
		mut fields := line.split('\t')
		if fields.len < 2 {
			continue
		}
		count := strconv.atoi(fields[1]) or { continue }
		out[fields[0]] = count
	}
	return out
}

// format_baseline renders results as the sorted `module<TAB>errors` table that
// read_baseline consumes.
fn format_baseline(results map[string]int) string {
	mut keys := results.keys()
	keys.sort()
	mut lines := []string{}
	for k in keys {
		lines << '${k}\t${results[k]}'
	}
	return lines.join('\n') + '\n'
}

fn usage() {
	println('Usage: v tests/corpus.vsh <package-root> [options]')
	println('')
	println('Options:')
	println('  -o <dir>        Where to write the generated tree (default: a temp dir)')
	println('  --baseline <f>  Compare against this baseline file, and write it with --update')
	println('  --update        Write the current results to --baseline and exit')
	println('  --jobs <n>      Compilers to run in parallel')
	println('  --top <n>       How many of the worst modules to list (default: 20)')
	println('  --keep          Keep the generated tree')
}

// main parses arguments, runs the corpus and reports.
fn main() {
	args := os.args[1..]
	if args.len == 0 || args[0] == '-h' || args[0] == '--help' {
		usage()
		exit(if args.len == 0 { 1 } else { 0 })
	}

	mut package_root := args[0]
	mut out_dir := ''
	mut baseline_path := ''
	mut update := false
	mut keep := false
	mut jobs := ''
	mut top := 20

	mut i := 1
	for i < args.len {
		arg := args[i]
		if arg == '-o' && i + 1 < args.len {
			out_dir = args[i + 1]
			i += 2
		} else if arg == '--baseline' && i + 1 < args.len {
			baseline_path = args[i + 1]
			i += 2
		} else if arg == '--jobs' && i + 1 < args.len {
			jobs = args[i + 1]
			i += 2
		} else if arg == '--top' && i + 1 < args.len {
			top = strconv.atoi(args[i + 1]) or { top }
			i += 2
		} else if arg == '--update' {
			update = true
			i++
		} else if arg == '--keep' {
			keep = true
			i++
		} else {
			eprintln('Unknown option: ${arg}')
			usage()
			exit(1)
		}
	}

	py2v := resolve_py2v()
	if !exists(py2v) {
		println('Building py2v...')
		res := os.exec(['v', project_dir, '-o', py2v])
		if res.exit_code != 0 {
			eprintln('ERROR: failed to build py2v')
			eprintln(res.output)
			exit(1)
		}
	}

	package_root = os.abs_path(package_root)
	// The baseline path is never inferred from the corpus. A corpus that lives
	// outside the repository has no business writing into it, and a directory
	// name makes a poor file name: scanning `portage/lib` would produce a
	// baseline called `lib.txt` that says nothing about what it measures.
	if update && baseline_path == '' {
		eprintln('ERROR: --update needs an explicit --baseline path')
		usage()
		exit(1)
	}
	script_name := os.base(os.abs_path(@FILE))
	mut temporary_out := out_dir == ''
	if temporary_out {
		out_dir = os.join_path(os.temp_dir(), 'py2v_corpus_' + script_name + '_' +
			os.getpid().str())
	}
	os.mkdir_all(out_dir) or { panic(err) }

	mut cmd := [py2v, '--package', package_root, '-o', out_dir, '--check']
	if jobs != '' {
		cmd << '--jobs'
		cmd << jobs
	}

	println('Translating and checking ' + package_root + '...')
	// The run is expected to fail: a corpus with errors exits non-zero, and
	// os.Result.output panics in that case. Drive the process directly so the
	// table can still be read.
	mut proc := os.new_process(cmd[0])
	proc.set_args(cmd[1..])
	proc.set_redirect_stdio_merged()
	proc.run()
	proc.wait()
	output := proc.stdout_slurp()

	// The per-file table goes to stdout, everything else to stderr; only the
	// table is machine readable.
	mut current := map[string]int{}
	mut clean := 0
	mut total := 0
	mut worst := []CheckLine{}
	for line in output.split('\n') {
		// py2v writes the table to stdout and its progress notes to stderr, and
		// os.Result merges the two. Only rows that look like `module<TAB>count`
		// are kept, so the noise is skipped rather than misparsed.
		if line.trim_space() == '' {
			continue
		}
		mut fields := line.split('\t')
		if fields.len < 2 {
			continue
		}
		count := strconv.atoi(fields[1]) or { continue }
		current[fields[0]] = count
		total += count
		if count == 0 {
			clean++
		}
		worst << CheckLine{
			name:   fields[0]
			errors: count
			first:  if fields.len > 2 {
				fields[2]
			} else {
				''
			}
		}
	}

	if temporary_out && !keep {
		os.rmdir_all(out_dir) or {}
	}

	println('')
	println('Generated modules: ' + current.len.str() + ', clean: ' + clean.str() +
		', total errors: ' + total.str())

	if current.len == 0 {
		eprintln('ERROR: no results were produced; the table on stdout was empty')
		eprintln(output)
		exit(1)
	}

	if update {
		os.mkdir_all(os.dir(baseline_path)) or { panic(err) }
		os.write_file(baseline_path, format_baseline(current)) or { panic(err) }
		println('Baseline written to ' + baseline_path)
		exit(0)
	}

	worst.sort_with_compare(fn (a &CheckLine, b &CheckLine) int {
		if a.errors != b.errors {
			return b.errors - a.errors
		}
		return compare_strings(a.name, b.name)
	})
	println('')
	println('Worst modules:')
	for entry in worst[..if worst.len < top { worst.len } else { top }] {
		if entry.errors > 0 {
			println('  ' + entry.name + ': ' + entry.errors.str() + '  ' + entry.first)
		}
	}

	if baseline_path == '' {
		println('')
		println('No --baseline given, so nothing to compare against.')
		println('Record one with --baseline <path> --update to track regressions later.')
		exit(0)
	}

	previous := read_baseline(baseline_path)
	if previous.len == 0 {
		println('')
		println('No baseline at ' + baseline_path + '; create one with --update.')
		exit(0)
	}

	mut regressed := []string{}
	mut improved := []string{}
	mut added := 0
	mut delta := 0
	for path, count in current {
		before := previous[path] or {
			added++
			continue
		}
		delta += count - before
		if count > before {
			regressed << path + ': ' + before.str() + ' -> ' + count.str()
		} else if count < before {
			improved << path + ': ' + before.str() + ' -> ' + count.str()
		}
	}
	mut removed := 0
	for path, count in previous {
		if path !in current {
			removed++
		}
	}

	println('')
	println('Baseline: ' + baseline_path)
	println('Total error delta: ' + (if delta > 0 { '+' + delta.str() } else { delta.str() }) +
		'  (new modules: ' + added.str() + ', missing modules: ' + removed.str() + ')')

	if regressed.len > 0 {
		println('')
		println('REGRESSED (' + regressed.len.str() + '):')
		for line in regressed {
			println('  ' + line)
		}
	}
	if improved.len > 0 {
		println('')
		println('IMPROVED (' + improved.len.str() + '):')
		for line in improved {
			println('  ' + line)
		}
	}
	if regressed.len > 0 {
		exit(1)
	}
}

// CheckLine is one row of the corpus result table.
struct CheckLine {
mut:
	name   string
	errors int
	first  string
}
