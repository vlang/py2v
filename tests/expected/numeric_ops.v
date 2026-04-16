@[translated]
module main

import math

fn main_func() {
	println(math.divide_floored(17, 5).quot)
	println(math.divide_floored(-17, 5).quot)
	println(17 % 5)
	println(-17 % 5)
	println(math.powi(2, 10))
	println(math.powi(3, 4))
	println(math.pow(2, -1))
	println(math.pow(10, -2))
	mut b := 2
	b = math.powi(b, 3)
	println(b)
	a := 100
	println(math.divide_floored(a, 7).quot)
	println(a % 7)
	println(math.powi(a, 2))
	mut c := -7
	c = math.divide_floored(c, 2).quot
	println(c)
	println(math.divide_floored(-5, 2).quot)
	println(-5 % 2)
}

fn main() {
	main_func()
}
