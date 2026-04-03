@[translated]
module main

fn main_func() {
	squares := []int{len: 5, init: index}.map((it * it))
	println(squares)
	evens := []int{len: 10, init: index}.filter((it % 2) == 0).map(it)
	println(evens)
}

fn main() {
	main_func()
}
