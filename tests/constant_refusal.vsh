import os

struct RefusalProbe {
	name   string
	body   string
	marker string
}

// A Python exception caught in the source must never become a V value or an
// uncatchable runtime panic. These unsupported operations fail at V checking.
fn main() {
	args := os.args[1..]
	if args.len != 2 {
		eprintln('Usage: v run tests/constant_refusal.vsh SCRATCH PY2V')
		exit(2)
	}
	work, py2v := args[0], args[1]
	os.mkdir_all(os.join_path(work, 'main')) or { panic(err) }
	probes := [
		RefusalProbe{'zero_negative_power', 'try:\n    print(0 ** -1)\nexcept ZeroDivisionError:\n    print("caught")', 'py2v_unsupported_negative_zero_power'},
		RefusalProbe{'zero_negative_pow_builtin', 'try:\n    print(pow(0, -1))\nexcept ZeroDivisionError:\n    print("caught")', 'py2v_unsupported_negative_zero_power'},
		RefusalProbe{'negative_shift_caught', 'try:\n    print(1 << -1)\nexcept ValueError:\n    print("caught")', 'py2v_unsupported_negative_shift_count'},
	]
	mut failed := 0
	for item in probes {
		path := os.join_path(work, item.name + '.py')
		native := os.join_path(work, 'main', item.name + '.v')
		source := "print('before')\n" + item.body + "\nprint('after')\n"
		os.write_file(path, source) or { panic(err) }
		python := os.exec(['python3', '-I', path])
		if python.exit_code != 0 || python.output != 'before\ncaught\nafter\n' {
			eprintln('${item.name}: CPython reference failed: ${python.output}')
			failed++
			continue
		}
		translated := os.exec([py2v, path, '-o', native])
		if translated.exit_code != 0 {
			eprintln('${item.name}: translation failed: ${translated.output}')
			failed++
			continue
		}
		module_path := '@vlib|' + os.getwd() + '|@vmodules'
		checked := os.exec([@VEXE, '-path', module_path, '-check', native])
		if checked.exit_code == 0 || !checked.output.contains(item.marker) {
			eprintln('${item.name}: checker exit ${checked.exit_code}, ${checked.output}')
			failed++
		}
	}
	println('constant refusal: ${probes.len} cases, ${failed} failed')
	if failed != 0 { exit(1) }
}
