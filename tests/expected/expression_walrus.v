module main

fn collect() []int {
	index := 0
	mut spans := [index,
		py2v_assign_expr1(&index, py2v_integer_add1(index, 1, 'expression_walrus.py:3', 'addition')),
		index]
	spans << py2v_assign_expr1(&index, py2v_integer_add1(index, 2, 'expression_walrus.py:4', 'addition'))
	println(index)
	return spans
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

fn py2v_assign_expr1[T](target &T, value T) T {
	unsafe { *target = value }
	return value
}

fn main() {
	println(collect())
}
