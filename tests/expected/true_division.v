module main

import strconv
import math

fn ratio(part int, whole int) f64 {
	return py2v_true_div1(part, whole)
}

fn py2v_true_div1(a f64, b f64) f64 {
	if b == 0 {
		panic('division by zero')
	}
	return a / b
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
	a := 7
	b := 2
	x := 2.5
	println(py2v_float_text1(py2v_true_div1(a, b)))
	println(py2v_float_text1(f64(a) / 2))
	println(py2v_float_text1(f64(7) / 2))
	println(py2v_float_text1(f64(a) / -2))
	println(py2v_float_text1(py2v_true_div1(f64(-a), b)))
	println(py2v_float_text1(py2v_true_div1(f64(~a), b)))
	println(py2v_float_text1(py2v_true_div1(f64(a + 1), b)))
	println(py2v_float_text1(py2v_true_div1(a, f64(b + 1))))
	println(py2v_float_text1(py2v_true_div1(a, b) / f64(b)))
	println(py2v_float_text1(math.floor(py2v_true_div1(a, b) / 1)))
	println(py2v_float_text1(math.pow(2, py2v_true_div1(a, b))))
	println(py2v_float_text1(py2v_true_div1(f64([1, 2, 3].len), b)))
	println(py2v_float_text1(py2v_true_div1(f64(math.powi(b, 3)), a)))
	half := py2v_true_div1(a, b)
	println(py2v_float_text1(half + 1))
	println(py2v_float_text1(ratio(1, 4)))
	println(py2v_float_text1(f64(a) / x))
	println(py2v_float_text1(x / f64(b)))
	println(math.divide_floored(a, b).quot)
	share := fn (a int, b int) int {
		return a / b
	}
	println(int(share(8, 2)))
	whole := fn () int {
		return int(py2v_true_div1(f64([1, 2, 3, 4].len), f64([5].len)))
	}
	println(whole())
	println(py2v_float_text1(f64(a) / 1 / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1)))
}
