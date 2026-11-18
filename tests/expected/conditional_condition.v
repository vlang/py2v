module main

fn choose(a bool, b bool, c bool) int {
	if true && (if c { a } else { b }) {
		return 3
	}
	return 7
}

fn main() {
	println(choose(true, false, true))
	println(choose(true, false, false))
}
