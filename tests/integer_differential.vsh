// Run with a scratch directory, the py2v executable, and optionally a seed.
import os

struct IntegerProbe {
	name string
	body string
	stop string
}

// probe runs the same source under CPython and as generated V. Decimal and float
// output are compared verbatim, including the prefix before a capability failure.
fn probe(work string, py2v string, item IntegerProbe) ! {
	py := os.join_path(work, item.name + '.py')
	native := os.join_path(work, 'main', item.name + '.v')
	bin := os.join_path(work, item.name + '.bin')
	source := "import math\ndef number(text: str) -> int:\n    return int(text)\nprint('before')\n" +
		item.body + "\nprint('after')\n"
	os.write_file(py, source)!
	reference := os.exec(['python3', '-I', py])
	if reference.exit_code != 0 {
		return error('CPython: ' + reference.output)
	}
	os.mkdir_all(os.dir(native))!
	translation := os.exec([py2v, py, '-o', native])
	if translation.exit_code != 0 {
		return error('translation: ' + translation.output)
	}
	module_path := '@vlib|' + os.getwd() + '|@vmodules'
	build := os.exec([@VEXE, '-path', module_path, '-o', bin, native])
	if build.exit_code != 0 {
		return error('build: ' + build.output)
	}
	result := os.exec(['timeout', '5', bin])
	if result.exit_code == 0 && result.output == reference.output {
		return
	}
	diagnostic := 'py2v_integer_overflow: '
	if item.stop != '' && result.exit_code == 1 && result.output.contains(diagnostic) {
		prefix := result.output.all_before(diagnostic)
		message := result.output.all_after(diagnostic).trim_space()
		lines := reference.output.split_into_lines()
		before_stop := if item.name == 'enumerate' { 2 } else { lines.len - 2 }
		if before_stop >= 1 && prefix.split_into_lines() == lines[..before_stop]
			&& message.ends_with(': ' + item.stop + ' exceeds the V int range') {
			return
		}
	}
	return error('CPython [${reference.output.trim_space()}], V exit ${result.exit_code} [${result.output.trim_space()}]')
}

fn main() {
	args := os.args[1..]
	if args.len !in [2, 3] {
		eprintln('Usage: v run tests/integer_differential.vsh SCRATCH PY2V [SEED]')
		exit(2)
	}
	seed := if args.len == 3 { args[2].u64() } else { u64(371921) }
	offset := int((seed ^ (seed >> 11)) % 1024) + 1
	max := '9223372036854775807'
	min := '-9223372036854775808'
	wide := '9223372036854775808'
	a := 'number("${max}")'
	b := 'number("${offset}")'
	low := 'number("${min}")'
	probes := [
		IntegerProbe{'ordinary', 'print(number("4294967296"))\nprint(number("9007199254740993"))\nprint(${a} ** number("1"))\nprint(${low} % number("-1"))\nprint(number("-19") >> number("4294967296"))\nprint(pow(number("2"), number("10"), number("-17")))\nprint(pow(number("2"), number("10")))\nprint(sum([-${b}, ${a}], ${b}))', ''},
		IntegerProbe{'add', 'print(${a} + ${b})', 'addition'},
		IntegerProbe{'computed_add', 'a = 1\nfor _ in range(62):\n    a *= 2\nprint(a + a)', 'addition'},
		IntegerProbe{'subtract', 'print(${low} - ${b})', 'subtraction'},
		IntegerProbe{'multiply', 'print(number("3037000500") * number("3037000500"))', 'multiplication'},
		IntegerProbe{'negate', 'print(-${low})', 'negation'},
		IntegerProbe{'absolute', 'print(abs(${low}))', 'absolute value'},
		IntegerProbe{'quotient', 'print(${low} // number("-1"))', 'floor division'},
		IntegerProbe{'shift', 'print(number("3") << number("63"))', 'left shift'},
		IntegerProbe{'power', 'print(number("2") ** number("1000"))', 'power'},
		IntegerProbe{'sum', 'print(sum([${b}], ${a}))', 'sum'},
		IntegerProbe{'factorial', 'print(math.factorial(number("100")))', 'factorial'},
		IntegerProbe{'decimal', 'print(number("${wide}"))', 'integer parsing'},
		IntegerProbe{'based', 'print(int("${wide}", 10))', 'integer parsing'},
		IntegerProbe{'float', 'print(int(float("${wide}")))', 'float to integer conversion'},
		IntegerProbe{'cancel', 'print((${a} + ${b}) - ${b})', 'addition'},
		IntegerProbe{'enumerate', 'for index, value in enumerate([3, 5], ${a}):\n    print(index, value)\nprint(0)', 'addition'},
		IntegerProbe{'bad_text', 'try:\n    print(number("184467440737095516160bad"))\nexcept ValueError:\n    print("invalid")', ''},
		IntegerProbe{'boxed_add', 'from typing import Any\ndef operation(x: Any, y: Any) -> Any:\n    return x + y\ntry:\n    print(operation(${a}, ${b}))\nexcept OverflowError:\n    print("caught")', 'addition'},
		IntegerProbe{'mixed_sum', 'print(sum([1, 2.0]))\nprint(sum([1, 2.5]))', ''},
		IntegerProbe{'square_root', 'print(math.isqrt(${a}))', ''},
		IntegerProbe{'greatest_divisor', 'print(math.gcd(${low}, 0))', 'greatest common divisor'},
		IntegerProbe{'least_multiple', 'print(math.lcm(${a}, 2))', 'least common multiple'},
		IntegerProbe{'nested_aug', 'def replace(rows: list[list[int]]) -> int:\n    rows[0] = [9]\n    return 2\nold = [3]\nrows = [old]\nrows[0][0] += replace(rows)\nprint(old, rows)', ''},
		IntegerProbe{'generic_add', 'from typing import TypeVar\nT = TypeVar("T")\ndef add(a: T, b: T) -> T:\n    return a + b\nprint(add("a", "b"))\nprint(add(${a}, ${b}))', 'addition'},
	]
	mut failed := 0
	for item in probes {
		probe(args[0], args[1], item) or {
			eprintln('${item.name}: ${err}')
			failed++
		}
	}
	println('seed ${seed}: ${probes.len - failed} passed, ${failed} failed')
	if failed != 0 {
		exit(1)
	}
}
