module main

import math
import strconv

fn area(radius f64) f64 {
	return math.pi * radius * radius
}

fn smallest(values []f64) f64 {
	mut best := math.inf(1)
	for value in values {
		if value < best {
			best = value
		}
	}
	return best
}

fn shadow(e int, values []int) int {
	pi := 3
	mut total := e + pi
	for tau in values {
		total = py2v_integer_add1(total, tau, 'math_from_import.py:31', 'addition')
	}
	return total
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

fn py2v_integer_generic_mul1[A, B, R](a A, b B, site string, fallback fn (A, B) R) R {
	$if A is $int && B is $int && R is $int {
		$if A is u64 || B is u64 || R is u64 {
			$compile_error('py2v_unsupported_wide_integer: generic arithmetic needs a signed native result')
		} $else {
			value := py2v_integer_mul1(int(a), int(b), site, 'multiplication')
			if value < int(math.minof[R]()) || value > int(math.maxof[R]()) {
				py2v_integer_overflow1(site, 'integer narrowing')
			}
			return R(value)
		}
	} $else {
		return fallback(a, b)
	}
}

fn main() {
	println(py2v_float_text1(area(2.0)))
	println(math.sqrt(16.0))
	println(math.round_sig(math.e, 3))
	println(py2v_float_text1(smallest([3.5, 1.25])))
	println(int(math.floor(f64(2.7))))
	println(math.round_sig(math.tau, 4))
	println(math.cos(0.0))
	println(if -math.inf(1) < 0 { 'True' } else { 'False' })
	println(shadow(1, [2, 3]))
	println(math.round_sig(py2v_integer_generic_mul1(math.sqrt(2), math.cos(math.pi), 'math_from_import.py:36', |py2v_operand1, py2v_operand2| py2v_operand1 * py2v_operand2), 6))
	n := 49
	println(math.sqrt(n))
}
