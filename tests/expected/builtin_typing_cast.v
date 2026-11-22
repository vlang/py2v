module main

fn produce() int {
	println('once')
	return 8
}

fn cast(first int, second int) int {
	return py2v_integer_add1(first, second, 'builtin_typing_cast.py:11', 'addition')
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	println(1)
	println('word')
	println([3, 4][0])
	println(produce())
	println(cast(4, 5))
}
