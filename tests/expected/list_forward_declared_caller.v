module main

fn entry() {
	mut x := [1]
	println(edit(mut x))
	println(x)
}

fn edit(mut a []int) []int {
	a << 3
	return a
}

fn main() {
	entry()
}
