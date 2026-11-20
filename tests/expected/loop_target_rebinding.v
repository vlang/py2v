module main

import pyrt

type Any = pyrt.Value

fn unpacked(upper int) int {
	left, mut value := 1, 8
	mut py2v_broke1 := false
	for value_ in []int{len: upper, init: index} {
		value = value_
		if value == 1 {
			value = 20
			py2v_broke1 = true
			break
		}
	}
	if !py2v_broke1 {
		println(value)
	}
	return left + value
}

fn distinct(n int) int {
	for n_ in []int{len: n, init: index} {
		println(n_)
	}
	return n
}

fn parameter(py2v_value_in2 int) int {
	mut value := py2v_value_in2
	for value_ in []int{len: value, init: index} {
		value = value_
		println(value_)
	}
	return value
}

fn dynamic_parameter(py2v_value_in3 Any) Any {
	mut value := py2v_value_in3
	for value_ in [3, 6] {
		value = value_
		// pass
	}
	return value
}

fn nested() int {
	mut result := 0
	for value in [1, 2] {
		mut py2v_iter_value4 := value
		for value_ in [4, 5] {
			py2v_iter_value4 = value_
			// pass
		}
		result += py2v_iter_value4
	}
	return result
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
