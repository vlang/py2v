module main

import pyrt

type Any = pyrt.Value

fn forward() int {
	read := py2v_unsupported_closure_forward_capture(fn (value int) int {
		return py2v_integer_add1(value, 1, 'unsupported_closure_capture.py:3', 'addition')
	})
	value := 4
	return read()
}

fn loop() int {
	mut result := 0
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(2)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value := py2v_range_start1; if py2v_range_step3 > 0 {
		value < py2v_range_stop2
	} else {
		value > py2v_range_stop2
	}; value = py2v_range_next1(value, py2v_range_stop2, py2v_range_step3) {
		read := py2v_unsupported_closure_loop_capture(fn (value int) int {
			return py2v_integer_add1(value, 2, 'unsupported_closure_capture.py:12', 'addition')
		})
		result = read()
	}
	return result
}

fn default(n int) int {
	py2v_default4 := py2v_integer_add1(n, 1, 'unsupported_closure_capture.py:18', 'addition')
	read := fn (x int) int {
		return py2v_integer_add1(x, 3, 'unsupported_closure_capture.py:19', 'addition')
	}
	return read(py2v_default4)
}

fn rebound_function() int {
	mut callback := fn () string {
		return 1
	}
	read := py2v_unsupported_closure_rebound_function(fn (callback Any) int {
		return callback()
	})
	callback = fn () string {
		return 2
	}
	return read()
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
