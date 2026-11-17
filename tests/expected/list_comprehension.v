module main

import math

fn main_func() {
	squares := []int{len: 5, init: index}.map(it * it)
	println(squares)
	evens := []int{len: 10, init: index}.filter(math.modulo_floored(it, 2) == 0).map(it)
	println(evens)
}

fn main() {
	main_func()
}
