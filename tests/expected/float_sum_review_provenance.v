module main

import math
import strconv

fn scaled(values []f64, factor f64) Py2vNumber {
	return py2v_float_sum_optional1(values.map(it * factor), 0)
}

fn variance(xs []f64, mean f64) f64 {
	return py2v_true_div1(py2v_float_sum_optional1(xs.map(math.pow(it - mean, 2)), 0).as_float(), f64(xs.len))
}

fn weighted_total(prices []f64, qty int, rate f64) Py2vNumber {
	return py2v_float_sum_optional1(prices.map(it * qty * rate), 0)
}

fn updated_work_buffer(scale int) f64 {
	mut data := [1e+16, 0.5, -1e+16]
	data[1] = f64(1) / 1
	return py2v_float_sum1([data[0] * scale, data[1] * scale, data[2] * scale], 0.0, true)
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

fn (value Py2vNumber) as_float() f64 {
	return match value {
		f64 { value }
		int { f64(value) }
	}
}

fn py2v_true_div1(a f64, b f64) f64 {
	if b == 0 {
		panic('division by zero')
	}
	return a / b
}

fn main() {
	println(scaled([1.0, 2.0], 2))
	println(scaled([0.5, 0.25], 4))
	println(py2v_float_text1(variance([1.0, 2.0, 3.0], 2)))
	println(py2v_float_text1(variance([1.0, 2.0, 3.0], 2.0)))
	println(weighted_total([1.5, 2.5], 2, 1))
	println(py2v_float_text1(updated_work_buffer(1)))
}
