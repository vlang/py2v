@[translated]
module main

import math

fn main_func() {
	println((math.divide_floored(17, 5).quot).str())
	println((math.divide_floored(-17, 5).quot).str())
	println((17 % 5).str())
	println((-17 % 5).str())
	println((math.powi(2, 10)).str())
	println((math.powi(3, 4)).str())
	println((math.pow(2, -1)).str())
	println((math.pow(10, -2)).str())
	mut b := 2
	b = math.powi(b, 3)
	println(b.str())
	a := 100
	println((math.divide_floored(a, 7).quot).str())
	println((a % 7).str())
	println((math.powi(a, 2)).str())
	mut c := -7
	c = math.divide_floored(c, 2).quot
	println(c.str())
	println((math.divide_floored(-5, 2).quot).str())
	println((-5 % 2).str())
}

fn main() {
	main_func()
}
