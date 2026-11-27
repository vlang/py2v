module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

fn note(value int) int {
	println('eval ${value}')
	return value
}

fn values(ch chan int, first int, bonus int, remaining ...int) {
	defer { ch.close() }
	ch <- first + bonus
	for item in remaining {
		ch <- item + bonus
	}
}

fn show() {
	// async for lowered to goroutine + channel
	py2v_gen_arg1 := note(1)
	py2v_gen_arg2 := note(2)
	py2v_gen_arg3 := note(3)
	py2v_ch4 := chan int{}
	go values(py2v_ch4, py2v_gen_arg1, py2v_gen_arg3, py2v_gen_arg2)
	for {
		item := <-py2v_ch4 or { break }
		println(item)
	}
	// async for lowered to goroutine + channel
	py2v_gen_arg5 := 6
	py2v_ch6 := chan int{}
	go values(py2v_ch6, 2, py2v_gen_arg5)
	for {
		item := <-py2v_ch6 or { break }
		println(item)
	}
}

fn main() {
	show()
}
