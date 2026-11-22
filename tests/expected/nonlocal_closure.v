module main

fn make_counter() fn () int {
	mut count := 0
	py2v_capture1 := &count
	increment := fn [py2v_capture1] () int {
		unsafe {
			(*py2v_capture1) = py2v_integer_add1((*py2v_capture1), 1, 'nonlocal_closure.py:6', 'addition')
		}
		return *py2v_capture1
	}
	return increment
}

fn make_adder(n int) fn (int) int {
	mut total := 0
	py2v_capture2 := &n
	py2v_capture3 := &total
	add := fn [py2v_capture2, py2v_capture3] (x int) int {
		unsafe {
			(*py2v_capture3) = py2v_integer_add1((*py2v_capture3), int(py2v_integer_add1(x, (*py2v_capture2), 'nonlocal_closure.py:17', 'addition')), 'nonlocal_closure.py:17', 'addition')
		}
		return *py2v_capture3
	}
	return add
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
	c := make_counter()
	println(c())
	println(c())
	add5 := make_adder(5)
	println(add5(1))
	println(add5(2))
}
