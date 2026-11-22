module main

import math
import strconv

fn collect(width int) []Py2vNumber {
	mut values := [0.0].repeat(math.max(0, int(width))).map(Py2vNumber(it))
	values << py2v_float_sum_optional1(py2v_range_array1(0, py2v_range_bound1(width), 1).map(f64(it)), 0)
	return values
}

fn total(xs []f64) Py2vNumber {
	return py2v_float_sum_optional1(xs.map(it / f64(1)), 0)
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

fn py2v_float_sum_uniform_tagged1(values []Py2vNumber) Py2vNumber {
	if values.len == 0 || values[0] is int { return Py2vNumber(0) }
	return Py2vNumber(py2v_float_sum1(values.map(it as f64), 0.0, true))
}

fn (value Py2vNumber) as_float() f64 {
	return match value {
		f64 { value }
		int { f64(value) }
	}
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn py2v_numeric_multiply1(a Py2vNumber, b Py2vNumber, site string) Py2vNumber {
	if a is int && b is int { return Py2vNumber(py2v_integer_mul1(a, b, site, 'multiplication')) }
	return Py2vNumber(a.as_float() * b.as_float())
}

fn py2v_numeric_round_sig1(value Py2vNumber, digits int) Py2vNumber {
	if value is int { return value }
	return Py2vNumber(math.round_sig(value as f64, digits))
}

fn py2v_numeric_add1(a Py2vNumber, b Py2vNumber) Py2vNumber {
	if a is int && b is int { return Py2vNumber(a + b) }
	return Py2vNumber(a.as_float() + b.as_float())
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

fn py2v_numeric_compare_int1(value Py2vNumber, other int) int {
	if value is int { return int(value > other) - int(value < other) }
	result := py2v_numeric_compare_float1(Py2vNumber(other), value as f64)
	return if result == 2 { 2 } else { -result }
}

fn main() {
	println(collect(0))
	println(collect(2))
	println(py2v_float_sum_uniform_tagged1(collect(2)))
	println(py2v_float_sum_uniform_tagged1(collect(0)))
	println(py2v_float_sum_uniform_tagged1(collect(-1)))
	println(py2v_numeric_multiply1(total([]), Py2vNumber(int(2)), 'float_sum_review_results.py:16'))
	println(py2v_numeric_multiply1(total([0.5]), Py2vNumber(int(2)), 'float_sum_review_results.py:17'))
	println(py2v_numeric_round_sig1(total([0.125, 0.25]), 2))
	println(py2v_numeric_add1(total([]), Py2vNumber(int(1))))
	println(py2v_float_text1(math.pow(total([1.5]).as_float(), 2.0)))
	println(py2v_float_text1(math.pow(total([]).as_float(), 2.0)))
	if py2v_numeric_compare_int1(total([0.75, 0.5]), int(1)) == 1 {
		println('big')
	}
}
