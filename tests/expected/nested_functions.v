module main

fn outer(x int) int {
	inner := fn (y int) int {
		return py2v_integer_mul1(y, 2, 'nested_functions.py:3', 'multiplication')
	}
	return inner(x) + 1
}

fn make_adder(n int) fn (int) int {
	py2v_capture1 := &n
	adder := fn [py2v_capture1] (x int) int {
		return x + (*py2v_capture1)
	}
	return adder
}

fn main_func() {
	println(outer(5))
	println(outer(10))
	add5 := make_adder(5)
	println(add5(10))
	println(add5(20))
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn main() {
	main_func()
}
