module main

import strconv

fn main_func() {
	println(int(3.7))
	println('42'.int())
	println(int(-3.9))
	println(py2v_float_text1(f64(42)))
	println('3.14')
	println((42).str())
	println('3.14')
	println('True')
	println(if !!(1 != 0) { 'True' } else { 'False' })
	println(if !!(0 != 0) { 'True' } else { 'False' })
	println(if !!('hello' != '') { 'True' } else { 'False' })
	println(if !!('' != '') { 'True' } else { 'False' })
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
