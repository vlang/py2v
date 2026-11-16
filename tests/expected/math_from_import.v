module main

import math

fn area(radius f64) f64 {
	return math.pi * radius * radius
}

fn smallest(values []f64) f64 {
	mut best := math.inf(1)
	for value in values {
		if value < best {
			best = value
		}
	}
	return best
}

fn shadow(e int, values []int) int {
	pi := 3
	mut total := e + pi
	for tau in values {
		total += tau
	}
	return total
}

fn main() {
	println(area(2))
	println(math.sqrt(16))
	println(math.round_sig(math.e, 3))
	println(smallest([3.5, 1.25]))
	println(int(math.floor(2.7)))
	println(math.round_sig(math.tau, 4))
	println(math.cos(0))
	println(if -math.inf(1) < 0 { 'True' } else { 'False' })
	println(shadow(1, [2, 3]))
	println(math.round_sig(math.sqrt(2) * math.cos(math.pi), 6))
	n := 49
	println(math.sqrt(n))
}
