module main

import arrays

fn collect(begin int, end int, step int) []int {
	return py2v_range_array1(py2v_range_bound1(begin), py2v_range_bound1(end), py2v_range_bound1(step)).clone()
}

fn from_bounds(bounds []int) int {
	return arrays.sum(py2v_range_array1(py2v_range_bound1(bounds[0]), py2v_range_bound1(bounds[1]), 1).map(py2v_integer_mul1(it, it, 'range_values.py:6', 'multiplication'))) or { 0 }
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
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

fn py2v_integer_power1(a int, b int, site string) int {
	if b < 0 { panic('py2v_unsupported_integer_power: a negative exponent needs a float result') }
	mut base, mut exponent := a, b
	mut result := 1
	for exponent != 0 {
		if exponent & 1 != 0 {
			result = py2v_integer_mul1(result, base, site, 'power')
		}
		exponent >>= 1
		if exponent != 0 {
			base = py2v_integer_mul1(base, base, site, 'power')
		}
	}
	return result
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
	println(py2v_range_array1(0, py2v_range_bound1(py2v_integer_power1(2, 3, 'range_values.py:17')), 1).clone())
	println(py2v_range_array1(py2v_range_bound1(py2v_integer_power1(2, 3, 'range_values.py:18')), py2v_range_bound1(py2v_integer_power1(3, 2, 'range_values.py:18')), 1).map(it))
	println(py2v_range_array1(0, py2v_range_bound1(true), 1).clone())
}
