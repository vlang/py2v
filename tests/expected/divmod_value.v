module main

import pyrt
import strconv

fn integer(a int, b int) int {
	return py2v_divmod_int1(a, b)[0] * 10 + py2v_divmod_int1(a, b)[1]
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

fn py2v_divmod_int1[A, B](a A, b B) []int {
	left := pyrt.box(a)
	right := pyrt.box(b)
	q := pyrt.floordiv(left, right) or { panic(err) }
	r := pyrt.mod(left, right) or { panic(err) }
	return [pyrt.to_int(q), pyrt.to_int(r)]
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
	result := py2v_divmod_int1(argument(7), argument(3))
	println(result[0])
	println(result[1])
}
