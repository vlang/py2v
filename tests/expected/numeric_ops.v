@[translated]
module main

import math

fn main_func() {
	println((math.divide_floored(17, 5).quot).str())
	println((math.divide_floored(-17, 5).quot).str())
	println((17 % 5).str())
	println((-17 % 5).str())
	println((2 ^ 10).str())
	println((3 ^ 4).str())
	a := 100
	println((math.divide_floored(a, 7).quot).str())
	println((a % 7).str())
	println((a ^ 2).str())
	mut c := -7
	c = math.divide_floored(c, 2).quot
	println(c.str())
	println((math.divide_floored(-5, 2).quot).str())
	println((-5 % 2).str())
}

fn main() {
	main_func()
}
