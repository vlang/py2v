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

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
}

fn main() {
	mut a := 1
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(5)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		a = forward(a)
	}
	println(a)
	mut b := 1
	py2v_range_start4 := int(0)
	py2v_range_stop5 := int(5)
	py2v_range_step6 := int(1)
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start4; if py2v_range_step6 > 0 {
		i < py2v_range_stop5
	} else {
		i > py2v_range_stop5
	}; i = py2v_range_next1(i, py2v_range_stop5, py2v_range_step6) {
		b = next_value(b)
	}
	println(b)
}
