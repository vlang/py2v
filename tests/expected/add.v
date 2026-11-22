module main

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
	mut num1 := 15
	mut num2 := 12
	sum := py2v_integer_add1(num1, num2, 'add.py:7', 'addition')
	num1 = 0
	num2 = 0
	println('Sum of ${num1} and ${num2} is ${sum}')
}
