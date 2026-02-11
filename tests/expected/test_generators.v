@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

// Test cases for generator functions and yield statements

fn simple_generator(ch chan Any) {
	defer { ch.close() }
	ch <- 1
	ch <- 2
	ch <- 3
}

fn generator_with_type(ch chan Any) {
	defer { ch.close() }
	mut x := 0
	for x < 5 {
		ch <- x
		x += 1
	}
}

fn generator_with_args(a int, b int, ch chan Any) {
	defer { ch.close() }
	for i in []int{len: b - a, init: index + a} {
		ch <- (i * 2)
	}
}

fn inner(ch chan Any) {
	defer { ch.close() }
	ch <- 1
	ch <- 2
}

fn generator_with_yield_from(ch chan Any) {
	defer { ch.close() }
	__gen1 := inner()
	// yield from __gen1
	for {
		val := <-__gen1 or { break }
		ch <- val
	}
	ch <- 3
}

fn generator_with_condition(ch chan Any) {
	defer { ch.close() }
	for i in []int{len: 10, init: index} {
		if (i % 2) == 0 {
			ch <- i
		}
	}
}

fn test_generator_calls() {
	gen1 := simple_generator()
	gen2 := generator_with_args(1, 5)
}
