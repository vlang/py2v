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
	py2v_range_start1 := int(a)
	py2v_range_stop2 := int(b)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
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
	py2v_gen4 := inner()
	// yield from py2v_gen4
	for {
		val := <-py2v_gen4 or { break }
		ch <- val
	}
	ch <- 3
}

fn generator_with_condition(ch chan int) {
	defer { ch.close() }
	py2v_range_start5 := int(0)
	py2v_range_stop6 := int(10)
	py2v_range_step7 := int(1)
	if py2v_range_step7 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start5; if py2v_range_step7 > 0 {
		i < py2v_range_stop6
	} else {
		i > py2v_range_stop6
	}; i = py2v_range_next1(i, py2v_range_stop6, py2v_range_step7) {
		if math.modulo_floored[int](i, 2) == 0 {
			ch <- i
		}
	}
}

fn test_generator_calls() {
	gen1 := simple_generator()
	gen2 := generator_with_args(1, 5)
}

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
}
