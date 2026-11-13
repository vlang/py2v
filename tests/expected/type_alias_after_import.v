module main

import math

type Score = int

fn bump(n Score) Score {
	return n + int(math.sqrt(4))
}

fn main_func() {
	println(bump(5))
}

fn main() {
	main_func()
}
