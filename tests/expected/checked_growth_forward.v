module main

fn twice(x int) int {
	return py2v_integer_add1(x, x, 'checked_growth_forward.py:2', 'addition')
}

fn forward(x int) int {
	return twice(x)
}

fn add(x int, y int) int {
	return py2v_integer_add1(x, y, 'checked_growth_forward.py:10', 'addition')
}

fn next_value(x int) int {
	return add(x, x)
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
	mut a := 1
	for i in int(0) .. int(5) {
		a = forward(a)
	}
	println(a)
	mut b := 1
	for i in int(0) .. int(5) {
		b = next_value(b)
	}
	println(b)
}
