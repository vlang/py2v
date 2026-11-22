module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

fn note(value int) int {
	println('eval ${value}')
	return value
}

fn values(ch chan i64, first int, bonus int, remaining ...int) {
	defer { ch.close() }
	ch <- py2v_integer_add1(first, bonus, 'variadic_generator_kwonly.py:10', 'addition')
	for item in remaining {
		ch <- py2v_integer_add1(item, bonus, 'variadic_generator_kwonly.py:12', 'addition')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	show()
}
