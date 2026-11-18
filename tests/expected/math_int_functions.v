module main

import math

fn count_coprime(limit int) int {
	mut total := 0
	for n in []int{len: limit - 1, init: index + 1} {
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
	for i in []int{len: int(math.sqrti(number)) + 1 - 2, init: index + 2} {
		if math.modulo_floored(number, i) == 0 {
			return false
		}
	}
	return true
}

fn choose(n int, r int) int {
	return math.divide_floored(int(math.factoriali(n)), int(math.factoriali(r)) * int(math.factoriali(n - r))).quot
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
