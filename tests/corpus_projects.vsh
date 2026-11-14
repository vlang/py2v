#!/usr/bin/env -S v

import os
import strconv
import sync

// Real-project check: translate pinned commits of open-source Python projects
// and make sure py2v still writes at least as many V files as it used to, and
// that at least as many of them still parse.
//
// tests/run_tests.vsh compares small programs with their expected V. This
// looks at whole projects instead, where a change can make py2v stop writing
// a file, or write one V no longer parses, without any small case noticing.
// Nothing from the projects is kept in this repository: each row of
// tests/corpus_projects.tsv names a repository, a commit, the package
// directory inside it, and the two minimum counts.
//
// Invoke it with:
//
//   v tests/corpus_projects.vsh [options]
//
// Options:
//   --tier <pr|nightly|all>  Which rows to run (default: pr)
//   --only <name>            Run one project by name, whatever its tier
//   --work <dir>             Where to clone and translate (default: a temp dir)
//   --jobs <n>               Parsers to run in parallel (default: 4)
//   --keep                   Keep the work directory
//
// Environment:
//   PY2V=<path>  use this py2v binary instead of the one beside this script
//
// The Python code is cloned and read. It is never run.

const script_dir = os.dir(os.abs_path(@FILE))
const project_dir = os.dir(script_dir)
const table_path = os.join_path(script_dir, 'corpus_projects.tsv')
const table_header = 'name\turl\tcommit\tpackage\ttier\tmin_translated\tmin_parsing'

struct Project {
	name           string
	url            string
	commit         string
	package        string
	tier           string
	min_translated int
	min_parsing    int
}

struct Outcome {
	translated int
	parsing    int
	problem    string
	// what py2v said about files it could not translate
	skipped string
}

// resolve_py2v returns the py2v binary to exercise. An explicit PY2V wins;
// otherwise the sibling binary is used, preferring `.exe` on Windows.
fn resolve_py2v() string {
	if override := os.getenv_opt('PY2V') {
		return override
	}
	bin := os.join_path(project_dir, 'py2v')
	if !os.exists(bin) && os.exists(bin + '.exe') {
		return bin + '.exe'
	}
	return bin
}

// read_table loads the rows of corpus_projects.tsv. Lines starting with `#`
// and empty lines are skipped; the first data line is the header.
fn read_table() ![]Project {
	mut projects := []Project{}
	mut header_seen := false
	for line in os.read_lines(table_path)! {
		if line.trim_space() == '' || line.starts_with('#') {
			continue
		}
		if !header_seen {
			// Without this, a table that lost its header would lose its first project.
			if line != table_header {
				return error('${table_path}: the first row must be the header `${table_header}`')
			}
			header_seen = true
			continue
		}
		cells := line.split('\t')
		if cells.len != 7 {
			return error('${table_path}: expected 7 tab-separated cells, got ${cells.len}: ${line}')
		}
		// strconv.atoi fails on text and on overflow, where `.int()` would give 0.
		min_translated := strconv.atoi(cells[5]) or { -1 }
		min_parsing := strconv.atoi(cells[6]) or { -1 }
		if min_translated < 0 || min_parsing < 0 {
			return error('${table_path}: a minimum must be a whole number: ${line}')
		}
		name := cells[0]
		if name == '' || name.starts_with('.') || name.contains('..') || !name.bytes().all(it.is_alnum() || it in [
			`-`,
			`_`,
			`.`,
		]) {
			return error('${table_path}: a name is letters, digits, `-`, `_` and `.`, got `${name}`')
		}
		if projects.any(it.name == name) {
			return error('${table_path}: ${name} is listed twice')
		}
		if cells[4] !in ['pr', 'nightly'] {
			return error('${table_path}: the tier of ${name} is `${cells[4]}`, expected pr or nightly')
		}
		if min_parsing > min_translated {
			return error('${table_path}: ${name} has more parsing files than written files as its minimums')
		}
		projects << Project{
			name:           cells[0]
			url:            cells[1]
			commit:         cells[2]
			package:        cells[3]
			tier:           cells[4]
			min_translated: min_translated
			min_parsing:    min_parsing
		}
	}
	return projects
}

// fetch puts the project's pinned commit in dir, with no history.
fn fetch(p Project, dir string) ! {
	os.mkdir_all(dir)!
	steps := [
		['init', '--quiet'],
		['remote', 'add', 'origin', p.url],
		['fetch', '--quiet', '--depth=1', 'origin', p.commit],
		['-c', 'advice.detachedHead=false', 'checkout', '--quiet', 'FETCH_HEAD'],
	]
	for step in steps {
		mut args := ['git', '-C', dir]
		args << step
		res := os.exec(args)
		if res.exit_code != 0 {
			return error('git ${step[0]} failed for ${p.name}: ${res.output.trim_space()}')
		}
	}
}

// parses reports whether `v -check-syntax` accepts one generated file. That
// command also parses the modules the file imports, so only an error reported
// at the file's own path counts against it.
fn parses(vexe string, file string) bool {
	res := os.exec([vexe, '-check-syntax', file])
	if res.exit_code == 0 {
		return true
	}
	own := os.real_path(file)
	mut diagnostics := 0
	for line in res.output.split_into_lines() {
		// path:line:column: error: message
		at := line.index(': error: ') or { continue }
		diagnostics++
		path := line[..at].all_before_last(':').all_before_last(':')
		if os.real_path(path) == own {
			return false
		}
	}
	// A failure without any diagnostic is V crashing or not starting, not a file
	// whose imports have errors.
	return diagnostics > 0
}

// count_parsing runs `parses` over files with a fixed number of workers.
fn count_parsing(vexe string, files []string, jobs int) int {
	tasks := chan int{cap: files.len}
	results := chan bool{cap: files.len}
	for i in 0 .. files.len {
		tasks <- i
	}
	tasks.close()
	mut wg := sync.new_waitgroup()
	// The waitgroup counts tasks, not workers, as in check.v.
	wg.add(files.len)
	for _ in 0 .. jobs {
		spawn fn [tasks, results, files, vexe, mut wg] () {
			for {
				task := <-tasks or { break }
				results <- parses(vexe, files[task])
				wg.done()
			}
		}()
	}
	wg.wait()
	results.close()
	mut ok := 0
	for {
		good := <-results or { break }
		if good {
			ok++
		}
	}
	return ok
}

// reports_skipped_files finds py2v's own report of files its frontend refused:
// `Skipped N file(s) that could not be translated:` with N above zero.
fn reports_skipped_files(output string) bool {
	for line in output.split_into_lines() {
		if line.starts_with('Skipped ') && line.ends_with(' file(s) that could not be translated:') {
			n := strconv.atoi(line.all_after('Skipped ').all_before(' ')) or { 0 }
			if n > 0 {
				return true
			}
		}
	}
	return false
}

// measure translates one project and counts what came out.
fn measure(p Project, py2v string, work string, jobs int) Outcome {
	// Start from nothing, so an earlier run's clone or output is never counted.
	own := os.join_path(work, p.name)
	if os.exists(own) {
		os.rmdir_all(own) or {
			return Outcome{
				problem: 'cannot clear ${own}: ${err.msg()}'
			}
		}
	}
	src := os.join_path(work, p.name, 'src')
	out := os.join_path(work, p.name, 'out')
	fetch(p, src) or {
		return Outcome{
			problem: err.msg()
		}
	}
	package_dir := os.join_path(src, p.package)
	if !os.is_dir(package_dir) {
		return Outcome{
			problem: 'no directory ${p.package} at ${p.commit}'
		}
	}
	// py2v exits 1 when it has to skip a file and says which; then the counts below
	// are what is judged. Any other failure fails the project.
	res := os.exec([py2v, '--package', package_dir, '-o', out])
	skipped := reports_skipped_files(res.output)
	if res.exit_code != 0 && !(res.exit_code == 1 && skipped) {
		return Outcome{
			problem: 'py2v exited ${res.exit_code}: ${res.output.trim_space().all_after_last('\n')}'
		}
	}
	files := os.walk_ext(out, '.v')
	if files.len == 0 {
		return Outcome{
			problem: 'py2v wrote no V file (exit ${res.exit_code}): ${res.output.trim_space().all_after_last('\n')}'
		}
	}
	return Outcome{
		translated: files.len
		parsing:    count_parsing(@VEXE, files, jobs)
		skipped:    if skipped {
			'Skipped ' + res.output.all_after('Skipped ').trim_space()
		} else {
			''
		}
	}
}

fn main() {
	mut tier := 'pr'
	mut only := ''
	mut work := ''
	mut jobs := 4
	mut keep := false
	args := os.args[1..]
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg == '--keep' {
			keep = true
		} else if arg in ['--tier', '--only', '--work', '--jobs'] && i + 1 < args.len {
			value := args[i + 1]
			match arg {
				'--tier' { tier = value }
				'--only' { only = value }
				'--work' { work = value }
				else { jobs = value.int() }
			}
			i++
		} else {
			eprintln('unknown argument: ${arg}')
			exit(2)
		}
		i++
	}
	if tier !in ['pr', 'nightly', 'all'] || jobs < 1 {
		eprintln('--tier takes pr, nightly or all; --jobs takes a positive number')
		exit(2)
	}
	py2v := resolve_py2v()
	if !os.exists(py2v) {
		eprintln('py2v binary not found at ${py2v}: build it with `v . -o py2v` first')
		exit(2)
	}
	projects := read_table() or {
		eprintln(err.msg())
		exit(2)
	}
	selected := projects.filter((only != '' && it.name == only)
		|| (only == '' && (tier == 'all' || it.tier == tier)))
	if selected.len == 0 {
		eprintln('no project selected')
		exit(2)
	}
	own_work := work == ''
	if own_work {
		work = os.join_path(os.vtmp_dir(), 'py2v_corpus_${os.getpid()}')
	}
	os.mkdir_all(work) or {
		eprintln('cannot create ${work}: ${err.msg()}')
		exit(2)
	}

	// The counts depend on both: the frontend parses with this Python, and newer
	// syntax in a project needs a newer Python.
	python := os.exec([$if windows { 'python' } $else { 'python3' }, '--version']).output.trim_space()
	println('${python}, ${os.exec([@VEXE, 'version']).output.trim_space()}')
	mut failed := 0
	println('project\ttranslated (min)\tparsing (min)\tresult')
	for p in selected {
		o := measure(p, py2v, work, jobs)
		mut result := 'ok'
		if o.problem != '' {
			result = 'FAIL: ${o.problem}'
		} else if o.translated < p.min_translated || o.parsing < p.min_parsing {
			result = 'FAIL: fewer than the minimum'
		} else if o.translated > p.min_translated || o.parsing > p.min_parsing {
			result = 'ok, and above the minimum: raise it in tests/corpus_projects.tsv'
		}
		if result.starts_with('FAIL') {
			failed++
		}
		println('${p.name}\t${o.translated} (${p.min_translated})\t${o.parsing} (${p.min_parsing})\t${result}')
		if result.starts_with('FAIL') && o.skipped != '' {
			println(o.skipped)
		}
	}
	// exit() does not run deferred code, so this comes before it.
	if own_work && !keep {
		os.rmdir_all(work) or {}
	}
	if failed > 0 {
		eprintln('${failed} of ${selected.len} projects failed')
		exit(1)
	}
}
