module main

import math

fn scaled_copy(source []int, denominator int, scale bool) []int {
	mut values := source.clone()
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(values.len)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for index := py2v_range_start1; if py2v_range_step3 > 0 {
		index < py2v_range_stop2
	} else {
		index > py2v_range_stop2
	}; index = py2v_range_next1(index, py2v_range_stop2, py2v_range_step3) {
		values[index] += 1
	}
	if scale {
		values = values.map(int(math.divide_floored(it, denominator).quot))
	}
	return values
}

fn squared_quotient(value int, denominator int) int {
	return math.divide_floored(math.powi(value, 2), denominator).quot
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
	entries := [20, -20, i64(8589934593), i64(25769803775)]
	println(scaled_copy(entries, 3, false))
	println(scaled_copy(entries, 3, true))
	println(scaled_copy(entries, -3, true))
	println(entries)
	println(squared_quotient(140000, 3))
}
