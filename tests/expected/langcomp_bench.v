module main

import math

fn test_python(iterations int) {
	mut iteration := 0
	mut total := f64(0.0)
	array_length := 1000
	array := py2v_range_array1(0, py2v_range_bound1(array_length), 1).map(it)
	println('iterations ${iterations}')
	for iteration < iterations {
		mut innerloop := 0
		for innerloop < 100 {
			total += array[math.modulo_floored(iteration + innerloop, array_length)]
			innerloop += 1
		}
		iteration += 1
	}
	if total == 15150 {
		println('OK')
	}
	// del array - V does not support deleting variables
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
	test_python(3)
}
