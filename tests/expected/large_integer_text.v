module main

import math.big as py2v_big

fn main() {
	left := u64(9223372036854775809)
	right := py2v_big.integer_from_string('-9223372036854775810') or { panic(err) }
	power := py2v_big.integer_from_string('2954312706550833698643') or { panic(err) }
	println(left.str() + ' ' + (right.str()).str() + ' ' + ('${power}').str())
	println('9223372036854775808 -9223372036854775808 1267650600228229401496703205376')
}
