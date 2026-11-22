module main

import math
import strconv

fn halved(value int) f64 {
	return f64(value) / 2
}

fn converted(value int) f64 {
	return f64(value)
}

fn filtered(values []f64) Py2vNumber {
	return py2v_float_sum_optional1(values.filter(it != 0.0), 0)
}

fn seeded_sum(count int) f64 {
	mut values := [f64(1) / 2]
	py2v_range_stop1 := int(count)
	for _ in int(0) .. py2v_range_stop1 {
		values << 2.0
	}
	reciprocals := values.map(f64(1) / it)
	return py2v_float_sum1(reciprocals, 0.0, true)
}

fn collected_sums(width int) []Py2vNumber {
	mut values := [0.0].repeat(math.max(0, int(width))).map(Py2vNumber(it))
	values << py2v_float_sum_optional1(py2v_range_array1(0, py2v_range_bound1(width), 1).map(f64(it)), 0)
	return values
}

type Py2vNumber = f64 | int

fn (value Py2vNumber) str() string {
	return match value {
		f64 { py2v_float_text1(value) }
		int { value.str() }
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

fn py2v_float_sum_optional1(values []f64, start int) Py2vNumber {
	if values.len == 0 { return Py2vNumber(start) }
	return Py2vNumber(py2v_float_sum1(values, f64(start), true))
}

@[inline]
fn py2v_range_bound1[T](value T) int {
	$if T is $int || T is bool {
		return int(value)
	} $else $if T is $sumtype {
		$for variant in T.variants {
			$if variant is $int || variant is bool {
				if value is variant {
					return int(value)
				}
			}
		}
		panic('TypeError: range needs integer bounds')
	} $else {
		$compile_error('py2v_unsupported_range_bound: range needs integer bounds')
	}
}

fn py2v_range_array1(start int, stop int, step int) []int {
	if step == 0 {
		panic('ValueError: range() arg 3 must not be zero')
	}
	mut values := []int{}
	for current := start; if step > 0 { current < stop } else { current > stop }; current += step {
		values << current
		if step > 0 {
			if u64(step) >= u64(stop) - u64(current) { break }
		} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
			break
		}
	}
	return values
}

fn main() {
	println(py2v_float_text1(py2v_float_sum1([1e+16 + 0.0, halved(1), -1e+16 * converted(1)], 0.0, true)))
	println(py2v_float_text1(py2v_float_sum1([1, 2, 3].map(halved(it)), 0.0, true)))
	samples := [1.0]
	println(py2v_float_sum_optional1(samples.filter(it < 0.0), 0))
	println(filtered([1e+16, 1.0, -1e+16]))
	mut changed := [1e+16, 0.0, -1e+16]
	changed[1] = f64(1)
	println(py2v_float_sum_optional1(changed, 0))
	println(py2v_float_text1(seeded_sum(0)))
	println(py2v_float_text1(seeded_sum(2)))
	println(collected_sums(0))
	println(collected_sums(2))
}
