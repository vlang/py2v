module main

import pyrt
import strconv

fn integer(a int, b int) int {
	return int(py2v_integer_mul1(py2v_integer_divmod1(a, b, 'divmod_value.py:2')[0], 10, 'divmod_value.py:2', 'multiplication')) + py2v_integer_divmod1(a, b, 'divmod_value.py:2')[1]
}

fn floating(a f64, b f64) f64 {
	py2v_unpack1 := py2v_divmod_float1(a, b)
	mut q := py2v_unpack1[0]
	mut r := py2v_unpack1[1]
	return q * 10.0 + r
}

fn argument(value int) int {
	println(value)
	return value
}

@[inline]
fn py2v_integer_floor_div1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return a / b - int(adjust)
}

@[inline]
fn py2v_integer_mod1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer modulo by zero') }
	if b == -1 { return 0 }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return if adjust { r + b } else { r }
}

fn py2v_integer_divmod1(a int, b int, site string) []int {
	return [py2v_integer_floor_div1(a, b, site), py2v_integer_mod1(a, b, site)]
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

fn py2v_divmod_float1[A, B](a A, b B) []f64 {
	left := pyrt.box(a)
	right := pyrt.box(b)
	q := pyrt.floordiv(left, right) or { panic(err) }
	r := pyrt.mod(left, right) or { panic(err) }
	return [pyrt.to_float(q), pyrt.to_float(r)]
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

fn main() {
	println(integer(7, 3))
	println(integer(-7, 3))
	println(integer(7, -3))
	println(py2v_float_text1(floating(7.5, 2.0)))
	result := py2v_integer_divmod1(argument(7), argument(3), 'divmod_value.py:20')
	println(result[0])
	println(result[1])
}
