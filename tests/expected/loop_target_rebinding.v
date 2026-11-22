module main

import pyrt

type Any = pyrt.Value

fn unpacked(upper int) int {
	left, mut value := 1, 8
	mut py2v_broke2 := false
	py2v_range_stop1 := int(upper)
	for value_ in int(0) .. py2v_range_stop1 {
		value = value_
		if value == 1 {
			value = 20
			py2v_broke2 = true
			break
		}
	}
	if !py2v_broke2 {
		println(value)
	}
	return left + value
}

fn distinct(n int) int {
	py2v_range_stop3 := int(n)
	for n_ in int(0) .. py2v_range_stop3 {
		println(n_)
	}
	return n
}

fn parameter(py2v_value_in4 int) int {
	mut value := py2v_value_in4
	py2v_range_stop5 := int(value)
	for value_ in int(0) .. py2v_range_stop5 {
		value = value_
		println(value_)
	}
	return value
}

fn dynamic_parameter(py2v_value_in6 Any) Any {
	mut value := py2v_value_in6
	for value_ in [3, 6] {
		value = value_
		// pass
	}
	return value
}

fn nested() int {
	mut result := 0
	for value in [1, 2] {
		mut py2v_iter_value7 := value
		for value_ in [4, 5] {
			py2v_iter_value7 = value_
			// pass
		}
		result = py2v_integer_add1(result, py2v_iter_value7, 'loop_target_rebinding.py:35', 'addition')
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

fn main() {
	println(unpacked(0))
	println(unpacked(3))
	println(distinct(2))
	println(parameter(2))
	mut original := 'initial'
	println(pyrt.str(dynamic_parameter(original)))
	println(original)
	println(nested())
}
