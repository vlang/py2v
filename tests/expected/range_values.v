module main

import arrays
import math

fn collect(begin int, end int, step int) []int {
	return py2v_range_array1(py2v_range_bound1(begin), py2v_range_bound1(end), py2v_range_bound1(step)).clone()
}

fn from_bounds(bounds []int) int {
	return arrays.sum(py2v_range_array1(py2v_range_bound1(bounds[0]), py2v_range_bound1(bounds[1]), 1).map(it * it)) or { 0 }
}

@[inline]
fn py2v_range_bound1[T](value T) int {
	$if T is $int || T is bool {
		return int(value)
	} $else $if T is $sumtype {
		$for variant in T.variants {
			$if variant is $int || variant is bool {
				if value is variant {
					return int(value)
				}
			}
		}
		panic('TypeError: range needs integer bounds')
	} $else {
		$compile_error('py2v_unsupported_range_bound: range needs integer bounds')
	}
}

fn py2v_range_array1(start int, stop int, step int) []int {
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
}

fn main() {
	limit := -3
	println(py2v_range_array1(0, py2v_range_bound1(limit), 1).clone())
	println(py2v_range_array1(py2v_range_bound1(3), py2v_range_bound1(limit), 1).clone())
	println(collect(1, 8, 3))
	println(collect(8, 1, -3))
	println(collect(1, 8, -3))
	println(from_bounds([4, 2]))
	println(from_bounds([-2, 2]))
	println(py2v_range_array1(0, py2v_range_bound1(math.powi(2, 3)), 1).clone())
	println(py2v_range_array1(py2v_range_bound1(math.powi(2, 3)), py2v_range_bound1(math.powi(3, 2)), 1).map(it))
	println(py2v_range_array1(0, py2v_range_bound1(true), 1).clone())
}
