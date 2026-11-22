module main

const py2v_numeric_1_800 = 1 << 8

const py2v_numeric_py2v_numeric_1_800 = 11

fn value() int {
	return py2v_integer_add1(py2v_numeric_1_800, py2v_numeric_py2v_numeric_1_800, 'decl_digit_name.py:6', 'addition')
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
	println(value())
}
