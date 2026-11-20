// purity.vsh [-lower]: hold the generated V in tests/expected to its budget of runtime use.
//
// py2v's output should be V a V programmer would write: plain V types and vlib calls. The
// runtime library (pyrt) is for Python behavior that plain V cannot express. This check keeps
// the suite's expected outputs from drifting the other way:
//
//   - tests/purity_budget.tsv lists, per expected file, how many of its lines may mention
//     `pyrt.`; a file that is not listed must have none;
//   - a file over its budget fails the check (emit plain V, or raise that file's line in the
//     same change and say in the pull request which Python behavior needs the runtime);
//   - a file under its budget fails too, so that the budget follows every improvement down:
//     run `v run tests/purity.vsh -lower`, which only ever lowers or removes lines;
//   - the row `@encoded-identifiers` bounds the `py2v_ident_<hex>` names in the same way;
//   - the rows `@runtime-lines`, `@runtime-public-functions` and `@runtime-unsafe` bound the
//     runtime library itself (the non-test V files under pyrt/), so that it can only shrink
//     unless a change raises a row by hand and says why.
import os

const budget_path = os.join_path(os.dir(@FILE), 'purity_budget.tsv')
const expected_dir = os.join_path(os.dir(@FILE), 'expected')
const encoded_row = '@encoded-identifiers'
const runtime_dir = os.join_path(os.dir(os.dir(@FILE)), 'pyrt')
const runtime_lines_row = '@runtime-lines'
const runtime_functions_row = '@runtime-public-functions'
const runtime_unsafe_row = '@runtime-unsafe'

fn read_budget() !map[string]int {
	mut budget := map[string]int{}
	for line in os.read_lines(budget_path)! {
		if line == '' || line.starts_with('#') {
			continue
		}
		parts := line.split('\t')
		if parts.len != 2 {
			return error('${budget_path}: expected "name<TAB>count", found "${line}"')
		}
		budget[parts[0]] = parts[1].int()
	}
	return budget
}

fn write_budget(budget map[string]int) ! {
	mut names := budget.keys()
	names.sort()
	mut out := [
		'# Lines mentioning `pyrt.` allowed per file in tests/expected; an unlisted file allows none.',
		'# Rows starting with @ bound totals: encoded identifiers in tests/expected, and the size of the runtime library in pyrt/.',
		'# Lower with `v run tests/purity.vsh -lower`. Raise a line only by hand, with the reason in the pull request.',
	]
	for name in names {
		if budget[name] > 0 {
			out << '${name}\t${budget[name]}'
		}
	}
	os.write_file(budget_path, out.join('\n') + '\n')!
}

// runtime_size counts the runtime library's own code: lines, public functions and lines using
// `unsafe` in the V files under pyrt/ that are not tests or test support.
fn runtime_size() !map[string]int {
	mut size := {
		runtime_lines_row:     0
		runtime_functions_row: 0
		runtime_unsafe_row:    0
	}
	for path in os.walk_ext(runtime_dir, '.v') {
		name := path[runtime_dir.len + 1..].replace('\\', '/')
		if name.ends_with('_test.v') || name.starts_with('tests-support/') {
			continue
		}
		for line in os.read_lines(path)! {
			size[runtime_lines_row]++
			if line.starts_with('pub fn ') {
				size[runtime_functions_row]++
			}
			if line.contains('unsafe') {
				size[runtime_unsafe_row]++
			}
		}
	}
	return size
}

fn main() {
	lower := '-lower' in os.args
	mut budget := read_budget() or {
		eprintln(err.msg())
		exit(2)
	}
	mut files := os.walk_ext(expected_dir, '.v').map(it[expected_dir.len + 1..].replace('\\',
		'/'))
	files.sort()
	mut actual := map[string]int{}
	mut importing := 0
	mut refs := 0
	mut lines := 0
	mut encoded := 0
	for name in files {
		text := os.read_file(os.join_path(expected_dir, name)) or {
			eprintln(err.msg())
			exit(2)
		}
		mut n := 0
		for line in text.split_into_lines() {
			lines++
			if line.contains('pyrt.') {
				n++
			}
			encoded += line.count('py2v_ident_')
		}
		if n > 0 {
			importing++
		}
		refs += n
		actual[name] = n
	}
	actual[encoded_row] = encoded
	runtime := runtime_size() or {
		eprintln(err.msg())
		exit(2)
	}
	for row, n in runtime {
		actual[row] = n
	}
	mut over := []string{}
	mut under := []string{}
	for name, n in actual {
		allowed := budget[name] or { 0 }
		if n > allowed {
			over << '  ${name}: ${n}, budget ${allowed}'
		} else if n < allowed {
			under << '  ${name}: ${n}, budget ${allowed}'
			budget[name] = n
		}
	}
	for name, _ in budget {
		if name !in actual {
			under << '  ${name}: no such expected file'
			budget[name] = 0
		}
	}
	per_thousand := if lines > 0 { refs * 1000 / lines } else { 0 }
	println('purity: ${files.len} expected files, ${importing} use pyrt, ${refs} pyrt lines (${per_thousand} per 1,000 lines), ${encoded} encoded identifiers')
	println('runtime: ${runtime[runtime_lines_row]} lines, ${runtime[runtime_functions_row]} public functions, ${runtime[runtime_unsafe_row]} lines using unsafe')
	over.sort()
	under.sort()
	if over.len > 0 {
		eprintln('over budget (emit plain V, or raise the line in tests/purity_budget.tsv and give the reason):')
		eprintln(over.join('\n'))
	}
	if under.len > 0 && lower {
		write_budget(budget) or {
			eprintln(err.msg())
			exit(2)
		}
		println('lowered ${under.len} budget lines')
	} else if under.len > 0 {
		eprintln('under budget (run `v run tests/purity.vsh -lower` and commit the result):')
		eprintln(under.join('\n'))
	}
	if over.len > 0 || (under.len > 0 && !lower) {
		exit(1)
	}
}
