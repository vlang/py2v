module main

import math

fn get_pair() []int {
	return [1, 2]
}

fn get_triple() []int {
	return [10, 20, 30]
}

fn divmod_custom(a int, b int) []int {
	return [math.divide_floored(a, b).quot, a % b]
}

fn main_func() {
	py2v_unpack1 := get_pair()
	mut x := py2v_unpack1[0]
	mut y := py2v_unpack1[1]
	println(x)
	println(y)
	py2v_unpack2 := get_triple()
	mut a := py2v_unpack2[0]
	mut b := py2v_unpack2[1]
	mut c := py2v_unpack2[2]
	println(a)
	println(b)
	println(c)
	py2v_unpack3 := divmod_custom(17, 5)
	mut quotient := py2v_unpack3[0]
	mut remainder := py2v_unpack3[1]
	println(quotient)
	println(remainder)
}

fn main() {
	main_func()
}
