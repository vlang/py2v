module main

import math
import strconv

fn py2v_float_sum1(values []f64, start f64, integer_start bool) f64 {
	mut total := start
	mut correction := 0.0
	mut first := 0
	if integer_start && values.len > 0 {
		total += values[0]
		first = 1
	}
	for value in values[first..] {
		next := total + value
		correction += if math.abs(total) >= math.abs(value) {
			(total - next) + value
		} else {
			(value - next) + total
		}
		total = next
	}
	return if correction != 0.0 && !math.is_inf(correction, 0) && !math.is_nan(correction) {
		total + correction
	} else {
		total
	}
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
	println(py2v_float_text1(py2v_float_sum1(['inf'.f64()], 0.0, true)))
	println(py2v_float_text1(py2v_float_sum1(['-inf'.f64()], 0.0, true)))
	println(py2v_float_text1(py2v_float_sum1(['nan'.f64()], 0.0, true)))
	println(py2v_float_text1(py2v_float_sum1(['inf'.f64(), '-inf'.f64()], 0.0, true)))
	println(py2v_float_text1(py2v_float_sum1(['inf'.f64(), 'nan'.f64()], 0.0, true)))
}
