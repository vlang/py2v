@[translated]
module main

fn main_func() {
	for i in []int{len: 3, init: index} {
		println(i.str())
	}
	for i in []int{len: 5 - 2, init: index + 2} {
		println(i.str())
	}
	for i := 0; i < 10; i += 2 {
		println(i.str())
	}
	for i := 5; i < 0; i += -1 {
		println(i.str())
	}
}

fn main() {
	main_func()
}
