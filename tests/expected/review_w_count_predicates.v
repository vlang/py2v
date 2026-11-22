module main

fn pred(x int) bool {
	println('pred ${x}')
	return x > 1
}

fn main_func() {
	println([1, 2, 3].count(pred(it)))
	println([1, 2, 3].count(pred(it) && pred(it + 1)))
}

fn main() {
	main_func()
}
