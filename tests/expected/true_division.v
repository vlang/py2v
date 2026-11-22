module main

import strconv
import math

fn ratio(part int, whole int) f64 {
	return py2v_true_div1(part, whole)
}

fn py2v_true_div1(a f64, b f64) f64 {
	if b == 0 {
		panic('division by zero')
	}
	return a / b
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_neg1(value int, site string) int {
	if value == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'negation') }
	return -value
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
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

@[inline]
fn py2v_integer_floor_div1(a int, b int, site string) int {
	if b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }
	if b == -1 && a == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'floor division') }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return a / b - int(adjust)
}

@[inline]
fn py2v_integer_from_float1(value f64, site string) int {
	if !(value >= -9223372036854775808.0 && value < 9223372036854775808.0) {
		py2v_integer_overflow1(site, 'float to integer conversion')
	}
	return int(value)
}

fn main() {
	a := 7
	b := 2
	x := 2.5
	println(py2v_float_text1(py2v_true_div1(a, b)))
	println(py2v_float_text1(f64(a) / 2))
	println(py2v_float_text1(f64(7) / 2))
	println(py2v_float_text1(f64(a) / -2))
	println(py2v_float_text1(py2v_true_div1(f64(py2v_integer_neg1(a, 'true_division.py:12')), b)))
	println(py2v_float_text1(py2v_true_div1(f64(~a), b)))
	println(py2v_float_text1(py2v_true_div1(f64(py2v_integer_add1(a, 1, 'true_division.py:14', 'addition')), b)))
	println(py2v_float_text1(py2v_true_div1(a, f64(py2v_integer_add1(b, 1, 'true_division.py:15', 'addition')))))
	println(py2v_float_text1(py2v_true_div1(a, b) / f64(b)))
	println(py2v_float_text1(math.floor(py2v_true_div1(a, b) / 1)))
	println(py2v_float_text1(math.pow(2, py2v_true_div1(a, b))))
	println(py2v_float_text1(py2v_true_div1(f64([1, 2, 3].len), b)))
	println(py2v_float_text1(py2v_true_div1(f64(py2v_integer_power1(b, 3, 'true_division.py:20')), a)))
	half := py2v_true_div1(a, b)
	println(py2v_float_text1(half + 1))
	println(py2v_float_text1(ratio(1, 4)))
	println(py2v_float_text1(f64(a) / x))
	println(py2v_float_text1(x / f64(b)))
	println(py2v_integer_floor_div1(a, b, 'true_division.py:26'))
	share := fn (a int, b int) int {
		return a / b
	}
	println(py2v_integer_from_float1(share(8, 2), 'true_division.py:28'))
	whole := fn () int {
		return py2v_integer_from_float1(py2v_true_div1(f64([1, 2, 3, 4].len), f64([5].len)), 'true_division.py:29')
	}
	println(whole())
	println(py2v_float_text1(f64(a) / 1 / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1)))
}
