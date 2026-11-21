module main

import math
import strconv

fn remainder(a f64, b f64) f64 {
	return py2v_float_mod1(f64(a), f64(b))
}

fn main_func() {
	for a in [-7.5, 7.5, -6.0, 6.0, 0.0, -0.0] {
		for b in [3.0, -3.0] {
			result := remainder(a, b)
			println('${py2v_float_text1(result)} ${math.copysign(1.0, result)}')
		}
	}
	mut value := -7.5
	py2v_old1 := value
	value = py2v_float_mod1(f64(py2v_old1), f64(3.0))
	println(py2v_float_text1(value))
	println('${py2v_float_text1(py2v_float_mod1(f64(-7), f64(3.5)))} ${py2v_float_text1(py2v_float_mod1(f64(7.5), f64(-3)))}')
}

fn py2v_float_mod1(a f64, b f64) f64 {
	if b == 0 { panic('float modulo by zero') }
	mut r := math.fmod(a, b)
	if r != 0 {
		if (r < 0) != (b < 0) { r += b }
	} else {
		r = math.copysign(0.0, b)
	}
	return r
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
	main_func()
}
