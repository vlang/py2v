module main

import arrays

fn zipped() int {
	mut result := 0
	py2v_seq1 := arrays.group([1, 2, 9], [3, 4], [5, 6])
	for py2v_item2 in py2v_seq1 {
		first := py2v_item2[0]
		second := py2v_item2[1]
		third := py2v_item2[2]
		result = py2v_integer_add1(result, int(py2v_integer_add1(int(py2v_integer_add1(first, second, 'loop_unpack_targets.py:4', 'addition')), third, 'loop_unpack_targets.py:4', 'addition')), 'loop_unpack_targets.py:4', 'addition')
	}
	return result
}

fn list_target() int {
	mut result := 0
	py2v_seq3 := [[2, 3], [4, 5]]
	for py2v_item4 in py2v_seq3 {
		first := py2v_item4[0]
		second := py2v_item4[1]
		result = py2v_integer_add1(result, int(py2v_integer_add1(first, second, 'loop_unpack_targets.py:11', 'addition')), 'loop_unpack_targets.py:11', 'addition')
	}
	return result
}

fn backward() int {
	mut result := 0
	py2v_seq5 := [[1, 2, 3], [4, 5, 6]].reverse()
	for py2v_item6 in py2v_seq5 {
		a := py2v_item6[0]
		b := py2v_item6[1]
		c := py2v_item6[2]
		result = py2v_integer_add1(int(py2v_integer_add1(int(py2v_integer_add1(int(py2v_integer_mul1(result, 10, 'loop_unpack_targets.py:18', 'multiplication')), a, 'loop_unpack_targets.py:18', 'addition')), b, 'loop_unpack_targets.py:18', 'addition')), c, 'loop_unpack_targets.py:18', 'addition')
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
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
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
	println(zipped())
	println(list_target())
	println(backward())
}
