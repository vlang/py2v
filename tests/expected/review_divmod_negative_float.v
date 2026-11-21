module main

import pyrt
import strconv

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
	py2v_unpack1 := py2v_divmod_float1(-4.5, 2.0)
	mut q := py2v_unpack1[0]
	mut r := py2v_unpack1[1]
	println('${py2v_float_text1(q)} ${py2v_float_text1(r)}')
}
