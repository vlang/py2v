module main

fn first() int {
	value := 10
	value_2 := 5
	return py2v_integer_add1(value, value_2, 'readable_local_identifiers.py:4', 'addition')
}

fn second() int {
	value := 1
	return value
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
	println('${first()} ${second()}')
}
