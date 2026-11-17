module main

import math

fn simple_generator(ch chan int) {
	defer { ch.close() }
	ch <- 1
	ch <- 2
	ch <- 3
}

fn generator_with_type(ch chan int) {
	defer { ch.close() }
	mut x := 0
	for x < 5 {
		ch <- x
		x += 1
	}
}

fn generator_with_args(a int, b int, ch chan i64) {
	defer { ch.close() }
	for i in []int{len: b - a, init: index + a} {
		ch <- i * 2
	}
}

fn generator_with_yield_from(ch chan int) {
	defer { ch.close() }
	inner := fn (ch chan int) {
		defer { ch.close() }
		ch <- 1
		ch <- 2
	}
	py2v_gen1 := inner()
	// yield from py2v_gen1
	for {
		val := <-py2v_gen1 or { break }
		ch <- val
	}
	ch <- 3
}

fn generator_with_condition(ch chan int) {
	defer { ch.close() }
	for i in []int{len: 10, init: index} {
		if math.modulo_floored(i, 2) == 0 {
			ch <- i
		}
	}
}

fn test_generator_calls() {
	gen1 := simple_generator()
	gen2 := generator_with_args(1, 5)
}
