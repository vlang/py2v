@[translated]
module main

import math

fn main_func() {
	println(math.abs(5))
	println(math.abs(-5))
	println(math.abs(0))
	println(math.round(3.7))
	println(math.round(3.2))
	println(math.round(3.5))
	println(math.round_sig(3.1415900000000003, 2))
	println(math.round_sig(2.71828, 3))
	println(math.abs(-3.14))
}

fn main() {
	main_func()
}
