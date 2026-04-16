@[translated]
module main

fn generator1(ch chan Any) {
	defer { ch.close() }
	ch <- 1
	ch <- 2
	ch <- 3
}

fn generator2(ch chan Any) {
	defer { ch.close() }
	ch <- 0
	__gen1 := generator1()
	// yield from __gen1
	for {
		val := <-__gen1 or { break }
		ch <- val
	}
	ch <- 4
}

fn show() {
	gen := generator2()
	for val in gen {
		println(val)
	}
}

fn main() {
	show()
}
