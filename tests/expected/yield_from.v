module main

fn generator1(ch chan int) {
	defer { ch.close() }
	ch <- 1
	ch <- 2
	ch <- 3
}

fn generator2(ch chan int) {
	defer { ch.close() }
	ch <- 0
	py2v_gen1 := generator1()
	// yield from py2v_gen1
	for {
		val := <-py2v_gen1 or { break }
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
