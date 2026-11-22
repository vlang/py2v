module main

fn add(args ...int) int {
	mut total := 0
	for n in args {
		total = py2v_integer_add1(total, n, 'splat_call.py:4', 'addition')
	}
	return total
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
	nums := [1, 2, 3]
	result := add(...nums)
	println(result)
}
