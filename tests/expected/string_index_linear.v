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
	s := 'ab'.repeat(50000)
	mut total := 0
	py2v_cached_chars_1 := s.split('')
	py2v_range_stop1 := int(py2v_cached_chars_1.len)
	for i in int(0) .. py2v_range_stop1 {
		py2v_old2 := total
		py2v_aug_result3 := py2v_integer_add1(py2v_old2, int(py2v_cached_chars_1[i].runes()[0]), 'string_index_linear.py:4', 'addition')
		total = py2v_aug_result3
	}
	println(total)
}
