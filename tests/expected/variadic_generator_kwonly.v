module main

import pyrt

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn note(value int) int {
	println('eval ${value}')
	return value
}

fn values(ch chan i64, first int, bonus int, remaining ...int) {
	defer { ch.close() }
	ch <- first + bonus
	for item in remaining {
		ch <- item + bonus
	}
}

fn show() {
	// async for lowered to goroutine + channel
	py2v_gen_arg2 := note(1)
	py2v_gen_arg3 := note(2)
	py2v_gen_arg4 := note(3)
	py2v_ch1 := chan i64{}
	go values(py2v_ch1, py2v_gen_arg2, py2v_gen_arg4, py2v_gen_arg3)
	for {
		item := <-py2v_ch1 or { break }
		println(item)
	}
	// async for lowered to goroutine + channel
	py2v_gen_arg6 := 6
	py2v_ch5 := chan i64{}
	go values(py2v_ch5, 2, py2v_gen_arg6)
	for {
		item := <-py2v_ch5 or { break }
		println(item)
	}
}

fn main() {
	show()
}
