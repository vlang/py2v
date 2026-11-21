module main

import math

fn test_python(iterations int) {
	mut iteration := 0
	mut total := f64(0.0)
	array_length := 1000
	array := py2v_range_array1(0, array_length, 1).map(it)
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
	test_python(3)
}
