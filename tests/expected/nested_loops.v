module main

fn main_func() {
	for i in int(0) .. int(3) {
		for j in int(0) .. int(3) {
			println(int(py2v_integer_mul1(i, 3, 'nested_loops.py:5', 'multiplication')) + j)
		}
	}
	for i in int(0) .. int(5) {
		for j in int(0) .. int(5) {
			if j == 2 {
				break
			}
			println(int(py2v_integer_mul1(i, 10, 'nested_loops.py:12', 'multiplication')) + j)
		}
	}
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
