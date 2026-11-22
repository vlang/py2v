module main

fn sub(a int, b int) int {
	return py2v_integer_sub1(a, b, 'call_binding.py:2', 'subtraction')
}

fn main_func() {
	println(sub(10, 1))
	println(area(3, 2, 3, 10))
	println(negative(3, -7))
	println(text("it's", '!'))
	println(descend(3))
	println(first([11]))
}

fn area(w int, h int, depth int, scale int) int {
	return py2v_integer_mul1(int(py2v_integer_mul1(int(py2v_integer_mul1(w, h, 'call_binding.py:15', 'multiplication')), depth, 'call_binding.py:15', 'multiplication')), scale, 'call_binding.py:15', 'multiplication')
}

fn negative(a int, b int) int {
	return py2v_integer_sub1(a, b, 'call_binding.py:19', 'subtraction')
}

fn text(a string, b string) string {
	return a + b
}

fn descend(n int) int {
	if n == 0 {
		return 0
	}
	return py2v_integer_add1(1, descend(py2v_integer_sub1(n, 1, 'call_binding.py:29', 'subtraction')), 'call_binding.py:29', 'addition')
}

fn first(xs []int) int {
	return xs[0]
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
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

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	main_func()
}
