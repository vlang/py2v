module main

fn show() {
	f := fn (x int) int {
		return x + 1
	}
	println(f(5))
}

fn main() {
	show()
}
