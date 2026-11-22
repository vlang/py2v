module main

fn difference(a int, b int) int {
	return a - b
}

fn main_func() {
	runner := difference
	println(difference(2, 5) + runner(5, 2))
}

fn main() {
	main_func()
}
