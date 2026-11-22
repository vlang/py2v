module main

const block_ = 2

const limit = 3

fn walk(n int) int {
	mut total := 0
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(n)
	py2v_range_step3 := int(block_)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for start := py2v_range_start1; if py2v_range_step3 > 0 {
		start < py2v_range_stop2
	} else {
		start > py2v_range_stop2
	}; start = py2v_range_next1(start, py2v_range_stop2, py2v_range_step3) {
		total = py2v_integer_add1(total, start, 'private_constant_loop_step.py:8', 'addition')
	}
	py2v_range_start4 := int(0)
	py2v_range_stop5 := int(n)
	py2v_range_step6 := int(limit)
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for start := py2v_range_start4; if py2v_range_step6 > 0 {
		start < py2v_range_stop5
	} else {
		start > py2v_range_stop5
	}; start = py2v_range_next1(start, py2v_range_stop5, py2v_range_step6) {
		total = py2v_integer_add1(total, start, 'private_constant_loop_step.py:10', 'addition')
	}
	return total
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
	println(walk(7))
}
