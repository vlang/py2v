module main

import math
import strconv

fn components(chroma f64, value f64) []Py2vNumber {
	saturation := if value == 0 { Py2vNumber(int(0)) } else { Py2vNumber(f64(chroma / value)) }
	return [Py2vNumber(f64(value)), saturation]
}

fn selected_saturation(chroma f64, value f64, zero int) Py2vNumber {
	return if value == 0 { Py2vNumber(int(zero)) } else { Py2vNumber(f64(chroma / value)) }
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

type Py2vNumber = f64 | int

fn (value Py2vNumber) str() string {
	return match value {
		f64 { py2v_float_text1(value) }
		int { value.str() }
	}
}

fn py2v_numeric_compare_float1(value Py2vNumber, other f64) int {
	if math.is_nan(other) { return 2 }
	if value is f64 {
		if math.is_nan(value) { return 2 }
		return int(value > other) - int(value < other)
	}
	if other >= 9223372036854775808.0 { return -1 }
	if other < -9223372036854775808.0 { return 1 }
	whole := int(other)
	signed := value as int
	if signed != whole { return int(signed > whole) - int(signed < whole) }
	return int(f64(whole) > other) - int(f64(whole) < other)
}

fn py2v_numeric_compare_from_float1(left f64, right Py2vNumber) int {
	return py2v_numeric_compare_float1(right, left)
}

fn main() {
	black := components(0.0, 0.0)
	color := components(0.25, 0.5)
	gray := components(0.0, 0.5)
	println('${black[1]} ${color[1]} ${gray[1]}')
	println((if black[1] is int { 'True' } else { 'False' }).str() + ' ' + (if color[1] is f64 {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if gray[1] is f64 { 'True' } else { 'False' }).str())
	println('${selected_saturation(0.0, 0.0, 0)} ${selected_saturation(0.25, 0.5, 0)}')
	println((if selected_saturation(0.0, 0.0, 0) is int { 'True' } else { 'False' }).str() + ' ' + (if selected_saturation(0.0, 0.5, 0) is f64 {
		'True'
	} else {
		'False'
	}).str())
	large := selected_saturation(0.0, 0.0, int(9007199254740993))
	println((if py2v_numeric_compare_float1(large, 9.007199254740992e+15) == 0 {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if py2v_numeric_compare_from_float1(9.007199254740992e+15, large) == 1 {
		'True'
	} else {
		'False'
	}).str())
}
