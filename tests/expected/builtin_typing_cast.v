module main

fn produce() int {
	println('once')
	return 8
}

fn cast(first int, second int) int {
	return first + second
}

fn main() {
	println(1)
	println('word')
	println([3, 4][0])
	println(produce())
	println(cast(4, 5))
}
