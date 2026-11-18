module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

fn async_gen(ch chan int) {
	defer { ch.close() }
	for i in []int{len: 3, init: index} {
		ch <- i
	}
}

fn show_async() {
	// async for lowered to goroutine + channel
	py2v_ch1 := chan int{}
	go async_gen(py2v_ch1)
	for {
		val := <-py2v_ch1 or { break }
		println(val)
	}
}

fn show() {
	show_async()
}

fn main() {
	show()
}
