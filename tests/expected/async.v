module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

fn async_gen(ch chan int) {
	defer { ch.close() }
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(3)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		ch <- i
	}
}

fn show_async() {
	// async for lowered to goroutine + channel
	py2v_ch4 := chan int{}
	go async_gen(py2v_ch4)
	for {
		val := <-py2v_ch4 or { break }
		println(val)
	}
}

fn show() {
	show_async()
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

fn main() {
	show()
}
