@[translated]
module main

fn inner(y int) int {
	return y * 2
}

fn outer(x int) int {
	return inner(x) + 1
}

fn adder(x int) int {
	return x + n
}

fn make_adder(n int) int {
	return adder
}

fn main_func() {
	println((outer(5)).str())
	println((outer(10)).str())
	add5 := make_adder(5)
	println((add5(10)).str())
	println((add5(20)).str())
}

fn main() {
	main_func()
}
