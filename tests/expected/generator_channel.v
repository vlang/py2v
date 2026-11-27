module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

pub struct Source {
pub mut:
	bias int = 10
}

fn (self Source) values(ch chan int, first int, bonus int, items ...int) {
	defer { ch.close() }
	ch <- int(first + bonus) + self.bias
	for item in items {
		ch <- int(item + bonus) + self.bias
	}
}

// @staticmethod
fn Source.static_values(ch chan int, xs ...int) {
	defer { ch.close() }
	for x in xs {
		ch <- x
	}
}

// @classmethod
fn Source.class_values(ch chan int, xs ...int) {
	defer { ch.close() }
	for x in xs {
		ch <- py2v_integer_mul1(x, 2, 'generator_channel.py:48', 'multiplication')
	}
}

fn forward_consumer() {
	// async for lowered to goroutine + channel
	py2v_ch1 := chan int{}
	go forward_values(py2v_ch1, 3, 4)
	for {
		item := <-py2v_ch1 or { break }
		println(item)
	}
}

fn forward_values(ch chan int, items ...int) {
	defer { ch.close() }
	for item in items {
		ch <- item
	}
}

fn colliding_channel(py2v_gen_ch chan int, ch int, rest ...int) {
	defer { py2v_gen_ch.close() }
	py2v_gen_ch <- ch
	for item in rest {
		py2v_gen_ch <- item + ch
	}
}

fn aliased_values(ch chan int, first int, remaining ...int) {
	defer { ch.close() }
	ch <- first
	for item in remaining {
		ch <- item
	}
}

fn sync_variadic(ch chan int, first int, remaining ...int) {
	defer { ch.close() }
	ch <- first
	for item in remaining {
		ch <- item
	}
}

fn with_nested_generator() []int {
	producer := fn (ch chan int, xs ...int) {
		defer { ch.close() }
		for x in xs {
			ch <- py2v_integer_mul1(x, 5, 'generator_channel.py:54', 'multiplication')
		}
	}
	return fn [producer] () []int {
		py2v_ch2 := chan int{}
		go producer(py2v_ch2, 2, 3)
		mut py2v_items3 := []int{}
		for {
			py2v_val4 := <-py2v_ch2 or { break }
			py2v_items3 << py2v_val4
		}
		return py2v_items3
	}()
}

fn void_with_nested_generator() {
	gen := fn (ch chan int, n int) {
		defer { ch.close() }
		ch <- n
	}
	println(fn [gen] () []int {
		py2v_ch5 := chan int{}
		go gen(py2v_ch5, 3)
		mut py2v_items6 := []int{}
		for {
			py2v_val7 := <-py2v_ch5 or { break }
			py2v_items6 << py2v_val7
		}
		return py2v_items6
	}())
}

fn show() {
	forward_consumer()
	// async for lowered to goroutine + channel
	py2v_ch8 := chan int{}
	go colliding_channel(py2v_ch8, 3, 4)
	for {
		item := <-py2v_ch8 or { break }
		println(item)
	}
	gen := aliased_values
	// async for lowered to goroutine + channel
	py2v_ch9 := chan int{}
	go gen(py2v_ch9, 2, 3, 4)
	for {
		item := <-py2v_ch9 or { break }
		println(item)
	}
	source := Source{}
	// async for lowered to goroutine + channel
	py2v_gen_arg10 := 1
	py2v_gen_arg11 := 2
	py2v_gen_arg12 := 5
	py2v_ch13 := chan int{}
	go source.values(py2v_ch13, py2v_gen_arg10, py2v_gen_arg12, py2v_gen_arg11)
	for {
		item := <-py2v_ch13 or { break }
		println(item)
	}
	println(fn () []int {
		py2v_ch14 := chan int{}
		go Source.static_values(py2v_ch14, 3, 4)
		mut py2v_items15 := []int{}
		for {
			py2v_val16 := <-py2v_ch14 or { break }
			py2v_items15 << py2v_val16
		}
		return py2v_items15
	}())
	println(fn () []int {
		py2v_ch17 := chan int{}
		go Source.class_values(py2v_ch17, 3, 4)
		mut py2v_items18 := []int{}
		for {
			py2v_val19 := <-py2v_ch17 or { break }
			py2v_items18 << py2v_val19
		}
		return py2v_items18
	}())
	println(fn () []int {
		py2v_ch20 := chan int{}
		go sync_variadic(py2v_ch20, 2, 3, 4)
		mut py2v_items21 := []int{}
		for {
			py2v_val22 := <-py2v_ch20 or { break }
			py2v_items21 << py2v_val22
		}
		return py2v_items21
	}())
	py2v_ch23 := chan int{}
	go sync_variadic(py2v_ch23, 8, 9)
	for {
		v_ := <-py2v_ch23 or { break }
		println(v_)
	}
	println(with_nested_generator())
	void_with_nested_generator()
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn main() {
	show()
}
