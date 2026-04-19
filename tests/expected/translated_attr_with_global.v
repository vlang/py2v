@[translated]
module main

fn set_x() {
	// global x: prefer mut parameter or struct field over __global
	x := 1
}

fn main() {
	x := 0
	set_x()
	println(x)
}
