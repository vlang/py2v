@[translated]
module main

fn main_func() {
	squares := []int{len: 5, init: index}.map((it * it))
	println(squares.str())
	evens := []int{len: 10, init: index}.filter((it % 2) == 0).map(it)
	println(evens.str())
}

fn main() {
	main_func()
}
