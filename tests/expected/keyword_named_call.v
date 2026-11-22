module main

fn @or(a int, b int) int {
	return a + b
}

fn main() {
	println([@or(2, 3), 6][0])
}
