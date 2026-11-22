module main

fn letters() string {
	println('iterable')
	return 'aé'
}

fn offset() int {
	println('start')
	return -2
}

fn total(values []int, start int) int {
	mut result := 0
	py2v_enumerated1 := values
	py2v_enum_start2 := start
	for py2v_enum_index3, v_ in py2v_enumerated1 {
		i := py2v_enum_index3 + py2v_enum_start2
		result = py2v_integer_add1(result, int(py2v_integer_mul1(i, v_, 'enumerate_start.py:14', 'multiplication')), 'enumerate_start.py:14', 'addition')
	}
	return result
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

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	py2v_enumerated4 := letters().split('')
	py2v_enum_start5 := offset()
	for py2v_enum_index6, char_ in py2v_enumerated4 {
		i := py2v_enum_index6 + py2v_enum_start5
		println('${i} ${char_}')
	}
	println(total([10, 20, 30], 4))
	println(total([], 9))
}
