module main

fn consecutive(n int) []int {
	return [n, n + 1]
}

fn main() {
	println(consecutive(7))
}
