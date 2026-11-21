module main

import arrays
import math

fn collect(begin int, end int, step int) []int {
	return py2v_range_array1(begin, end, step).clone()
}

fn from_bounds(bounds []int) int {
	return arrays.sum(py2v_range_array1(bounds[0], bounds[1], 1).map(it * it)) or { 0 }
}

fn py2v_range_array1[A, B, C](begin A, end B, stride C) []int {
	$if (A is $int || A is bool) && (B is $int || B is bool) && (C is $int || C is bool) {
		start := int(begin)
		stop := int(end)
		step := int(stride)
		if step == 0 {
			panic('ValueError: range() arg 3 must not be zero')
		}
		mut values := []int{}
		for current := start; if step > 0 { current < stop } else { current > stop }; current += step {
			values << current
			if step > 0 {
				if u64(step) >= u64(stop) - u64(current) { break }
			} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
				break
			}
		}
		return values
	} $else {
		$compile_error('py2v_unsupported_range_bound: range needs integer bounds')
	}
}

fn main() {
	limit := -3
	println(py2v_range_array1(0, limit, 1).clone())
	println(py2v_range_array1(3, limit, 1).clone())
	println(collect(1, 8, 3))
	println(collect(8, 1, -3))
	println(collect(1, 8, -3))
	println(from_bounds([4, 2]))
	println(from_bounds([-2, 2]))
	println(py2v_range_array1(0, math.powi(2, 3), 1).clone())
	println(py2v_range_array1(math.powi(2, 3), math.powi(3, 2), 1).map(it))
	println(py2v_range_array1(0, true, 1).clone())
}
