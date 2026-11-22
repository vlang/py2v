module main

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
	s := 'ab'.repeat(50000)
	mut total := 0
	py2v_cached_chars_1 := s.split('')
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(py2v_cached_chars_1.len)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		py2v_old4 := total
		py2v_aug_result5 := py2v_integer_add1(py2v_old4, int(py2v_cached_chars_1[i].runes()[0]), 'string_index_linear.py:4', 'addition')
		total = py2v_aug_result5
	}
	println(total)
}
