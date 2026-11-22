module main

fn show() {
	myfunc := fn (x int, y int) int {
		return x + y
	}
	println(myfunc(1, 2))
}

fn main() {
	show()
}
