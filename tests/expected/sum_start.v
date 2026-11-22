module main

import arrays
import strconv

fn main_func() {
	xs := [1, 2, 3]
	fs := [1.5, 2.5]
	base := 10
	step := 2
	println(py2v_integer_sum1(xs, 10, 'sum_start.py:6'))
	println(py2v_integer_sum1(xs, base, 'sum_start.py:7'))
	println(py2v_float_text1(arrays.fold(fs, f64(0.5), |acc, x| acc + x)))
	println(py2v_float_text1(arrays.fold(fs, f64(10), |acc, x| acc + x)))
	println(py2v_float_text1(arrays.fold(fs, f64(base), |acc, x| acc + x)))
	println(py2v_float_text1(arrays.fold(xs, f64(0.5), |acc, x| acc + x)))
	println(py2v_integer_sum1([]int{len: 4, init: index}, 3, 'sum_start.py:12'))
	println(py2v_integer_mul1(py2v_integer_sum1(xs, 10, 'sum_start.py:13'), 2, 'sum_start.py:13', 'multiplication'))
	println(py2v_integer_sum1(xs, 10, 'sum_start.py:14'))
	println(py2v_integer_sum1(xs, -1, 'sum_start.py:15'))
	println(py2v_integer_sum1(xs, base - step, 'sum_start.py:16'))
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

fn py2v_integer_sum1[T](items []T, start int, site string) int {
	$if (T is $int && T !is u64) || T is bool {
		mut total := start
		for item in items { total = py2v_integer_add1(total, int(item), site, 'sum') }
		return total
	} $else {
		$compile_error('py2v_unsupported_integer_sum: expected native integer elements')
	}
}

fn py2v_float_text1[T](value T) string {
	$if T is $float {
		scientific := strconv.f64_to_str(f64(value), 16)
		marker := scientific.index('e') or { return scientific.trim_left('+') }
		exponent := scientific[marker + 1..].int()
		if exponent < -4 || exponent >= 16 {
			return scientific
		}
		sign := if scientific.starts_with('-') { '-' } else { '' }
		digits := scientific[sign.len..marker].replace('.', '')
		point := exponent + 1
		if point <= 0 {
			return sign + '0.' + '0'.repeat(-point) + digits
		}
		if point >= digits.len {
			return sign + digits + '0'.repeat(point - digits.len) + '.0'
		}
		return sign + digits[..point] + '.' + digits[point..]
	} $else {
		return value.str()
	}
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

fn main() {
	main_func()
}
