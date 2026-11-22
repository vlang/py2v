module main

import strconv

fn result() int {
	return 3
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
	mut x := 1
	x = 1
	println(x)
	println(x.str())
	println('${x}')
	mut y := 1
	for i in int(0) .. int(2) {
		if i != 0 {
			y = 2
		}
	}
	println(py2v_float_text1(y))
	mut z := 1
	z = result()
	println(py2v_float_text1(z))
}
