@[translated]
module main

fn show() {
	gen := []int{len: 5, init: index}.map((it * it))
	for val in gen {
		println(val.str())
	}
}

fn main() {
	show()
}
