module main

import arrays
import strconv

fn main_func() {
	xs := [1, 2, 3]
	fs := [1.5, 2.5]
	base := 10
	step := 2
	println((arrays.sum(xs) or { 0 }) + 10)
	println((arrays.sum(xs) or { 0 }) + base)
	println(py2v_float_text1(arrays.fold(fs, f64(0.5), |acc, x| acc + x)))
	println(py2v_float_text1(arrays.fold(fs, f64(10), |acc, x| acc + x)))
	println(py2v_float_text1(arrays.fold(fs, f64(base), |acc, x| acc + x)))
	println(py2v_float_text1(arrays.fold(xs, f64(0.5), |acc, x| acc + x)))
	println((arrays.sum([]int{len: 4, init: index}) or { 0 }) + 3)
	println(((arrays.sum(xs) or { 0 }) + 10) * 2)
	println((arrays.sum(xs) or { 0 }) + 10)
	println((arrays.sum(xs) or { 0 }) + -1)
	println((arrays.sum(xs) or { 0 }) + (base - step))
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
