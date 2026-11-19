module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

fn values(ch chan int, first int, remaining ...int) {
	defer { ch.close() }
	ch <- first
	for item in remaining {
		ch <- item
	}
}

fn show() {
	// async for lowered to goroutine + channel
	py2v_ch1 := chan int{}
	go values(py2v_ch1, 1)
	for {
		item := <-py2v_ch1 or { break }
		println(item)
	}
	// async for lowered to goroutine + channel
	py2v_ch2 := chan int{}
	go values(py2v_ch2, 2, 3, 4)
	for {
		item := <-py2v_ch2 or { break }
		println(item)
	}
}

fn main() {
	show()
}
