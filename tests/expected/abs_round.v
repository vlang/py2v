module main

import math
import strconv

fn main_func() {
	println(math.abs(5))
	println(math.abs(-5))
	println(math.abs(0))
	println(4)
	println(3)
	println(4)
	println('3.14')
	println('2.718')
	println(py2v_float_text1(f64(math.abs(-3.14))))
}

fn py2v_float_text1(value f64) string {
	scientific := strconv.f64_to_str(value, 16)
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
}

fn main() {
	main_func()
}
