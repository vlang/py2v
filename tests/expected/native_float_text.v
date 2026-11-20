module main

import strconv

fn echo(x f64) f64 {
	println((py2v_float_text1(f64(x))).str() + '|' + (py2v_float_text1(f64(x))).str() + '|' + ('${py2v_float_text1(f64(x))}').str())
	return x
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
	one := 1.0
	minus_zero := -0.0
	println(py2v_float_text1(f64(echo(one))))
	println(py2v_float_text1(f64(echo(minus_zero))))
	values := [0.0001, 1e-05, 1e+15, 1e+16, 5e-324, 1.2345678901234567]
	println('${py2v_float_text1(f64(values[0]))} ${py2v_float_text1(f64(values[1]))} ${py2v_float_text1(f64(values[2]))} ${py2v_float_text1(f64(values[3]))} ${py2v_float_text1(f64(values[4]))} ${py2v_float_text1(f64(values[5]))}')
	println((py2v_float_text1(f64(echo('inf'.f64())))).str() + ' ' + (py2v_float_text1(f64(echo('-inf'.f64())))).str() + ' ' + (py2v_float_text1(f64(echo('nan'.f64())))).str())
}
