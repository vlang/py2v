module py_pkg_call_defaults_consumer

import py_pkg_call_defaults
import strconv

pub fn run_float_defaults() {
	println(py2v_float_text1(py_pkg_call_defaults.zero_default(0.0)))
	println(py2v_float_text1(py_pkg_call_defaults.unit_default(1.0)))
	println(py2v_float_text1(py_pkg_call_defaults.negative_default(-2.0)))
	println(py2v_float_text1(py_pkg_call_defaults.negative_zero_default(-0.0)))
	py_pkg_call_defaults.float_any_default(0.0)
	py_pkg_call_defaults.int_any_default(0)
	println(py2v_float_text1(py_pkg_call_defaults.zero_default(2.5)))
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
