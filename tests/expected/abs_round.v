@[translated]
module main

import math

fn main_func() {
	println((math.abs(5)).str())
	println((math.abs(-5)).str())
	println((math.abs(0)).str())
	println((math.round(3.7)).str())
	println((math.round(3.2)).str())
	println((math.round(3.5)).str())
	println((math.round_sig(3.1415900000000003, 2)).str())
	println((math.round_sig(2.71828, 3)).str())
	println((math.abs(-3.14)).str())
}

fn main() {
	main_func()
}
