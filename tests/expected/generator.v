@[translated]
module main

type Any = bool | int | i64 | f64 | string | []u8

fn simple_generator(ch chan Any) {
	defer { ch.close() }
	ch <- 1
	ch <- 2
	ch <- 3
}

fn show() {
	gen := simple_generator()
	for val in gen {
		println(val)
	}
}

fn main() {
	show()
}
