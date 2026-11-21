module main

import math
import strconv

fn area(radius f64) f64 {
	return math.pi * radius * radius
}

fn smallest(values []f64) f64 {
	mut best := math.inf(1)
	for value in values {
		if value < best {
			best = value
		}
	}
	return best
}

fn shadow(e int, values []int) int {
	pi := 3
	mut total := e + pi
	for tau in values {
		total += tau
	}
	return total
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
	println(py2v_float_text1(area(2.0)))
	println(math.sqrt(16.0))
	println(math.round_sig(math.e, 3))
	println(py2v_float_text1(smallest([3.5, 1.25])))
	println(int(math.floor(2.7)))
	println(math.round_sig(math.tau, 4))
	println(math.cos(0.0))
	println(if -math.inf(1) < 0 { 'True' } else { 'False' })
	println(shadow(1, [2, 3]))
	println(math.round_sig(math.sqrt(2) * math.cos(math.pi), 6))
	n := 49
	println(math.sqrt(n))
}
