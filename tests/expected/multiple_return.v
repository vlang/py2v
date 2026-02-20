@[translated]
module main

import math

fn get_pair() []int {
	return [1, 2]
}

fn get_triple() []int {
	return [10, 20, 30]
}

fn divmod_custom(a int, b int) []int {
	return [math.divide_floored(a, b).quot, (a % b)]
}

fn main_func() {
	__unpack1 := get_pair()
	mut x := __unpack1[0]
	mut y := __unpack1[1]
	println(x.str())
	println(y.str())
	__unpack2 := get_triple()
	mut a := __unpack2[0]
	mut b := __unpack2[1]
	mut c := __unpack2[2]
	println(a.str())
	println(b.str())
	println(c.str())
	__unpack3 := divmod_custom(17, 5)
	mut quotient := __unpack3[0]
	mut remainder := __unpack3[1]
	println(quotient.str())
	println(remainder.str())
}

fn main() {
	main_func()
}
