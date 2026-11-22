@[has_globals]
module main

import arrays

fn reset() {
	// global x: prefer mut parameter or struct field over __global
	x := 1
}

fn main() {
	x := 1.5
	reset()
	println(arrays.sum([1]) or { 0 })
}
