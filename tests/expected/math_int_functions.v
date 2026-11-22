module main

import math

fn count_coprime(limit int) int {
	mut total := 0
	py2v_range_start1 := int(1)
	py2v_range_stop2 := int(limit)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for n := py2v_range_start1; if py2v_range_step3 > 0 {
		n < py2v_range_stop2
	} else {
		n > py2v_range_stop2
	}; n = py2v_range_next1(n, py2v_range_stop2, py2v_range_step3) {
		if math.gcd(n, limit) == 1 {
			total += 1
		}
	}
	return total
}

fn is_prime(number int) bool {
	if number < 2 {
		return false
	}
	for i in py2v_range_array1(py2v_range_bound1(2), py2v_range_bound1(int(math.sqrti(number)) + 1), 1) {
		if math.modulo_floored[int](number, i) == 0 {
			return false
		}
	}
	return true
}

fn choose(n int, r int) int {
	return math.divide_floored(int(math.factoriali(n)), int(math.factoriali(r)) * int(math.factoriali(n - r))).quot
}

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
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
	println('${math.gcd(12, 18)} ${math.gcd(12, 18)}')
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
