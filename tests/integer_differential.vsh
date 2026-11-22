// Run with a scratch directory, the py2v executable, and optionally a seed.
import os

struct IntegerProbe {
	name string
	body string
	stop string
}

struct PlainProbe {
	IntegerProbe
	output string
}

// probe runs the same source under CPython and as generated V. Decimal and float
// output are compared verbatim, including the prefix before a capability failure.
fn probe(work string, py2v string, item IntegerProbe, plain_output string) ! {
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
	if plain_output != '' {
		if result.exit_code == 0 && result.output == 'before\n' + plain_output + '\nafter\n'
			&& result.output != reference.output {
			return
		}
		return error('native V output [${plain_output}], got exit ${result.exit_code} [${result.output.trim_space()}]')
	}
	if item.stop == '' && result.exit_code == 0 && result.output == reference.output {
		return
	}
	diagnostic := 'py2v_integer_overflow: '
	if item.stop != '' && result.exit_code == 1 && result.output.contains(diagnostic) {
		prefix := result.output.all_before(diagnostic)
		message := result.output.all_after(diagnostic).trim_space()
		lines := reference.output.split_into_lines()
		before_stop := lines.len - 2
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
		IntegerProbe{'folded_literal', 'def identity(value: int) -> int:\n    return value\na = 2 ** 40\nprint(a, identity(a), identity(2 ** 62))', ''},
		IntegerProbe{'multiply', 'print(number("3037000500") * number("3037000500"))', 'multiplication'},
		IntegerProbe{'loop_add', 'a = ${a}\nfor _ in range(2):\n    a += ${b}\nprint(a)', 'addition'},
		IntegerProbe{'loop_tuple', 'a = ${a}\nb = ${b}\nfor _ in range(2):\n    a, b = b, a + b\nprint(b)', 'addition'},
		IntegerProbe{'loop_copy', 'a = ${a}\nb = ${b}\nfor _ in range(2):\n    next_value = a + b\n    a, b = b, next_value\nprint(b)', 'addition'},
		IntegerProbe{'loop_append', 'values = [${a}, ${b}]\nfor _ in range(2):\n    values.append(values[-2] + values[-1])\nprint(values[-1])', 'addition'},
		IntegerProbe{'loop_call', 'def increment(value: int) -> int:\n    return int(value) + ${b}\na = ${a}\nfor _ in range(2):\n    a = increment(a)\nprint(a)', 'addition'},
		IntegerProbe{'shift', 'print(number("3") << number("63"))', 'left shift'},
		IntegerProbe{'power', 'print(number("2") ** number("1000"))', 'power'},
		IntegerProbe{'sum', 'print(sum([${b}], ${a}))', 'sum'},
		IntegerProbe{'sum_call', 'def values() -> list[int]:\n    return [${a}, ${b}]\nprint(sum(values()))', 'sum'},
		IntegerProbe{'sum_comprehension', 'print(sum([value for value in [${a}, ${b}]]))', 'sum'},
		IntegerProbe{'factorial', 'print(math.factorial(number("100")))', 'factorial'},
		IntegerProbe{'decimal', 'print(number("${wide}"))', 'integer parsing'},
		IntegerProbe{'based', 'print(int("${wide}", 10))', 'integer parsing'},
		IntegerProbe{'cancel', 'print((${a} + ${b}) - ${b})', ''},
		IntegerProbe{'bad_text', 'try:\n    print(number("184467440737095516160bad"))\nexcept ValueError:\n    print("invalid")', ''},
		IntegerProbe{'boxed_add', 'from typing import Any\ndef operation(x: Any, y: Any) -> Any:\n    return x + y\ntry:\n    print(operation(${a}, ${b}))\nexcept OverflowError:\n    print("caught")', 'addition'},
		IntegerProbe{'mixed_sum', 'print(sum([1, 2.0]))\nprint(sum([1, 2.5]))', ''},
		IntegerProbe{'square_root', 'print(math.isqrt(${a}))', ''},
		IntegerProbe{'nested_aug', 'def replace(rows: list[list[int]]) -> int:\n    rows[0] = [9]\n    return 2\nold = [3]\nrows = [old]\nrows[0][0] += replace(rows)\nprint(old, rows)', ''},
		IntegerProbe{'aug_old_value', 'def replace(items: list[int]) -> int:\n    items[0] = 30\n    return 2\nitems = [3]\nitems[0] += replace(items)\nprint(items)', ''},
		IntegerProbe{'inferred_power', 'from typing import TypeVar\nT = TypeVar("T")\ndef squared(value: T) -> T:\n    return value ** 2\nprint(squared(3), squared(0.5))', ''},
		IntegerProbe{'guarded_local', 'def parse(text: str) -> int:\n    try:\n        index: int = int(text)\n    except ValueError:\n        return -1\n    return index\nprint(parse("bad"), parse("4294967296"))', ''},
		IntegerProbe{'masked_right_shift', 'def reduced(text: str) -> int:\n    state = 5\n    for x in text:\n        state = ((state << 20) >> 1) + ord(x)\n    return state & 0xFFFFFFFF\nprint(reduced("abcdefghi"))', 'left shift'},
		IntegerProbe{'list_repetition', 'print([math.pi] * 2)', ''},
	]
	// These operations have V's native signed behavior outside a growth point.
	// Keep the CPython difference visible instead of treating it as an exact match.
	wrapped_add := (i64(-9223372036854775807) + offset - 2).str()
	wrapped_subtract := (i64(9223372036854775807) - offset + 1).str()
	mut plain := [
		PlainProbe{IntegerProbe{'add', 'print(${a} + ${b})', ''}, wrapped_add},
		PlainProbe{IntegerProbe{'computed_add', 'a = 1\nfor _ in range(62):\n    a *= 2\nprint(a + a)', ''}, min},
		PlainProbe{IntegerProbe{'subtract', 'print(${low} - ${b})', ''}, wrapped_subtract},
		PlainProbe{IntegerProbe{'negate', 'print(-${low})', ''}, min},
		PlainProbe{IntegerProbe{'absolute', 'print(abs(${low}))', ''}, min},
		PlainProbe{IntegerProbe{'enumerate', 'for index, value in enumerate([3, 5], ${a}):\n    print(index, value)\nprint(0)', ''}, '${max} 3\n${min} 5\n0'},
		PlainProbe{IntegerProbe{'generic_add', 'from typing import TypeVar\nT = TypeVar("T")\ndef add(a: T, b: T) -> T:\n    return a + b\nprint(add("a", "b"))\nprint(add(${a}, ${b}))', ''}, 'ab\n${wrapped_add}'},
		PlainProbe{IntegerProbe{'greatest_divisor', 'print(math.gcd(${low}, 0))', ''}, max},
		PlainProbe{IntegerProbe{'least_multiple', 'print(math.lcm(${a}, 2))', ''}, max},
	]
	// These two native results depend on the target's conversion and division instructions.
	$if macos && arm64 {
		plain << PlainProbe{IntegerProbe{'quotient', 'print(${low} // number("-1"))', ''}, min}
		plain << PlainProbe{IntegerProbe{'float_to_int', 'print(int(float("${wide}")))', ''}, max}
	}
	mut failed := 0
	for item in probes {
		probe(args[0], args[1], item, '') or {
			eprintln('${item.name}: ${err}')
			failed++
		}
	}
	growth_count := probes.filter(it.stop != '' && it.name != 'boxed_add').len
	for item in plain {
		probe(args[0], args[1], item.IntegerProbe, item.output) or {
			eprintln('${item.name}: ${err}')
			failed++
		}
	}
	println('seed ${seed}: ${growth_count} growth, ${plain.len} plain V, ${probes.len - growth_count} compatibility probes, ${failed} failed')
	if failed != 0 {
		exit(1)
	}
}
