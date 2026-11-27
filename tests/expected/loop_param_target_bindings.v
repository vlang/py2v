module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

pub struct InitLoopBox {
pub mut:
	tag int = 0
}

fn (mut self InitLoopBox) init(py2v_rows_in4 []int) {
	mut rows := py2v_rows_in4
	for rows_ in [[1, 2, 3], [4, 5]] {
		rows = unsafe { rows_ }
		// pass
	}
	self.tag = rows.len
}

pub fn py2v_new_init_loop_box(rows []int) InitLoopBox {
	mut py2v_instance := InitLoopBox{}
	py2v_instance.init(rows)
	return py2v_instance
}

fn discard_then_loop(pair []int) int {
	py2v_unpack1 := pair
	mut x := py2v_unpack1[0]
	_ = py2v_unpack1[1]
	for _ in int(0) .. int(3) {
		x = py2v_integer_add1(x, 1, 'loop_param_target_bindings.py:7', 'addition')
	}
	return x
}

fn nested_try_match_while() int {
	mut total := 0
	for x in [1, 2] {
		mut py2v_iter_value2 := x
		defer {
			// pass
		}
		for x_ in [10, 20] {
			py2v_iter_value2 = x_
			// pass
		}
		total = py2v_integer_add1(total, py2v_iter_value2, 'loop_param_target_bindings.py:19', 'addition')
	}
	return total
}

fn nonlocal_loop_read() int {
	mut x := 0
	py2v_capture3 := &x
	bump := fn [py2v_capture3] () {
		unsafe {
			(*py2v_capture3) = 99
		}
	}
	for x_ in [1, 2] {
		x = x_
		bump()
		println(x)
	}
	return x
}

fn walrus_and_loop_param(flag bool, x int) int {
	mut py2v_walrus_arg5 := x
	mut py2v_walrus6 := flag
	if py2v_walrus6 {
		py2v_walrus_arg5 = 10
		py2v_walrus6 = py2v_walrus_arg5 > 0
	}
	if py2v_walrus6 {
		// pass
	}
	for py2v_walrus_iter7 in [4, 5] {
		py2v_walrus_arg5 = py2v_walrus_iter7
		// pass
	}
	return py2v_walrus_arg5
}

fn tuple_pair_rebind() int {
	mut a, mut b := 0, 0
	py2v_seq8 := [[1, 2], [3, 4]]
	for py2v_item9 in py2v_seq8 {
		a_ := py2v_item9[0]
		b_ := py2v_item9[1]
		a = a_
		b = b_
		// pass
	}
	mut total := a + b
	py2v_seq10 := [[5, 6], [7, 8]]
	for py2v_item11 in py2v_seq10 {
		_ = py2v_item11[0]
		b_ := py2v_item11[1]
		b = b_
		total = py2v_integer_add1(total, b_, 'loop_param_target_bindings.py:59', 'addition')
	}
	return total
}

fn tuple_pair_strings() string {
	mut out := ''
	py2v_seq12 := ['xy', 'zw']
	for py2v_item13 in py2v_seq12 {
		py2v_runes14 := py2v_item13.runes()
		a := py2v_runes14[0].str()
		b := py2v_runes14[1].str()
		out += b + a
	}
	return out
}

fn closure_struct_rebind() int {
	inner := fn (mut box InitLoopBox) int {
		box.tag = 5
		defer {
			// pass
		}
		mut py2v_param_rebind15 := box
		for box_ in [py2v_new_init_loop_box([1]), py2v_new_init_loop_box([1, 2, 3])] {
			py2v_param_rebind15 = box_
			// pass
		}
		return py2v_param_rebind15.tag
	}
	mut orig := py2v_new_init_loop_box([9])
	return int(py2v_integer_mul1(inner(mut orig), 10, 'loop_param_target_bindings.py:81', 'multiplication')) + orig.tag
}

fn values(ch chan int) {
	defer { ch.close() }
	ch <- 10
	ch <- 20
}

fn main_func() {
	println(discard_then_loop([10, 20]))
	println(nested_try_match_while())
	println(nonlocal_loop_read())
	orig := [9]
	println('${py2v_new_init_loop_box(orig).tag} ${orig}')
	println('${walrus_and_loop_param(true, 1)} ${walrus_and_loop_param(false, 1)}')
	println(tuple_pair_rebind())
	println(tuple_pair_strings())
	println(closure_struct_rebind())
	mut item := 0
	// async for lowered to goroutine + channel
	py2v_ch16 := chan int{}
	go values(py2v_ch16)
	for {
		item_ := <-py2v_ch16 or { break }
		item = item_
		// pass
	}
	println(item)
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
	main_func()
}
