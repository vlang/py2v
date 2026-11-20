module main

import pyrt

type Any = pyrt.Value

fn unpacked(upper int) int {
	left, mut value := 1, 8
	mut py2v_broke4 := false
	py2v_range_start1 := 0
	py2v_range_stop2 := upper
	py2v_range_step3 := 1
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value_ := py2v_range_start1; if py2v_range_step3 > 0 {
		value_ < py2v_range_stop2
	} else {
		value_ > py2v_range_stop2
	}; value_ = py2v_range_next1(value_, py2v_range_stop2, py2v_range_step3) {
		value = value_
		if value == 1 {
			value = 20
			py2v_broke4 = true
			break
		}
	}
	if !py2v_broke4 {
		println(value)
	}
	return left + value
}

fn distinct(n int) int {
	py2v_range_start5 := 0
	py2v_range_stop6 := n
	py2v_range_step7 := 1
	if py2v_range_step7 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for n_ := py2v_range_start5; if py2v_range_step7 > 0 {
		n_ < py2v_range_stop6
	} else {
		n_ > py2v_range_stop6
	}; n_ = py2v_range_next1(n_, py2v_range_stop6, py2v_range_step7) {
		println(n_)
	}
	return n
}

fn parameter(py2v_value_in8 int) int {
	mut value := py2v_value_in8
	py2v_range_start9 := 0
	py2v_range_stop10 := value
	py2v_range_step11 := 1
	if py2v_range_step11 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value_ := py2v_range_start9; if py2v_range_step11 > 0 {
		value_ < py2v_range_stop10
	} else {
		value_ > py2v_range_stop10
	}; value_ = py2v_range_next1(value_, py2v_range_stop10, py2v_range_step11) {
		value = value_
		println(value_)
	}
	return value
}

fn dynamic_parameter(py2v_value_in12 Any) Any {
	mut value := py2v_value_in12
	for value_ in [3, 6] {
		value = value_
		// pass
	}
	return value
}

fn nested() int {
	mut result := 0
	for value in [1, 2] {
		mut py2v_iter_value13 := value
		for value_ in [4, 5] {
			py2v_iter_value13 = value_
			// pass
		}
		result += py2v_iter_value13
	}
	return result
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
	println(unpacked(0))
	println(unpacked(3))
	println(distinct(2))
	println(parameter(2))
	mut original := 'initial'
	println(pyrt.str(dynamic_parameter(original)))
	println(original)
	println(nested())
}
