module main

import pyrt

type Any = pyrt.Value

fn values_at(data []Any) []int {
	start, stop, step := data[0], data[1], data[2]
	return py2v_range_array1(py2v_range_bound1(start), py2v_range_bound1(stop), py2v_range_bound1(step))
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
	println(values_at([-2, 5, 2].map(Any(it))))
	println(values_at([7, -2, -3].map(Any(it))))
	println(values_at([2, -1, 1].map(Any(it))))
	println(values_at([false, true, true].map(Any(it))))
}
