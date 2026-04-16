@[translated]
module main

fn simple_generator(ch chan int) {
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
