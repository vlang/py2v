module main

import math

fn count_coprime(limit int) int {
	mut total := 0
	py2v_range_stop1 := int(limit)
	for n in int(1) .. py2v_range_stop1 {
		if math.gcd[int](n, limit) == 1 {
			total = py2v_integer_add1(total, 1, 'math_int_functions.py:9', 'addition')
		}
	}
	return total
}

fn is_prime(number int) bool {
	if number < 2 {
		return false
	}
	for i in py2v_range_array1(py2v_range_bound1(2), py2v_range_bound1(py2v_integer_isqrt1(number) + 1), 1) {
		if math.modulo_floored[int](number, i) == 0 {
			return false
		}
	}
	return true
}

fn choose(n int, r int) int {
	return math.divide_floored(py2v_integer_factorial1(n, 'math_int_functions.py:23'), py2v_integer_generic_mul1(py2v_integer_factorial1(r, 'math_int_functions.py:23'), py2v_integer_factorial1(n - r, 'math_int_functions.py:23'), 'math_int_functions.py:23', |py2v_operand2, py2v_operand3| py2v_operand2 * py2v_operand3)).quot
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn py2v_integer_isqrt1(value int) int {
	if value < 0 { panic('ValueError: isqrt() argument must be nonnegative') }
	mut remainder := u64(value)
	mut root := u64(0)
	mut bit := u64(1) << 62
	for bit > remainder { bit >>= 2 }
	for bit != 0 {
		trial := root + bit
		root >>= 1
		if remainder >= trial {
			remainder -= trial
			root += bit
		}
		bit >>= 2
	}
	return int(root)
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

@[inline]
fn py2v_integer_factorial1(value int, site string) int {
	if value < 0 { panic('ValueError: factorial() not defined for negative values') }
	if value > 20 { py2v_integer_overflow1(site, 'factorial') }
	return int(math.factoriali(value))
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

fn py2v_integer_generic_mul1[A, B, R](a A, b B, site string, fallback fn (A, B) R) R {
	$if A is $int && B is $int && R is $int {
		$if A is u64 || B is u64 || R is u64 {
			$compile_error('py2v_unsupported_wide_integer: generic arithmetic needs a signed native result')
		} $else {
			value := py2v_integer_mul1(int(a), int(b), site, 'multiplication')
			if value < int(math.minof[R]()) || value > int(math.maxof[R]()) {
				py2v_integer_overflow1(site, 'integer narrowing')
			}
			return R(value)
		}
	} $else {
		return fallback(a, b)
	}
}

fn main() {
	println('${math.gcd[int](12, 18)} ${math.gcd[int](12, 18)}')
	println('${int(math.sqrti(17))} ${int(math.sqrti(99))}')
	println('${int(math.factoriali(5))} ${int(math.factoriali(6))}')
	println(count_coprime(12))
	println((if is_prime(97) { 'True' } else { 'False' }).str() + ' ' + (if is_prime(91) {
		'True'
	} else {
		'False'
	}).str())
	println(choose(10, 3))
}
