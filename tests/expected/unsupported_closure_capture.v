module main

import pyrt

type Any = pyrt.Value

fn forward() int {
	read := py2v_unsupported_closure_forward_capture(fn (value int) int {
		return value + 1
	})
	value := 4
	return read()
}

fn loop() int {
	mut result := 0
	for value in int(0) .. int(2) {
		read := py2v_unsupported_closure_loop_capture(fn (value int) int {
			return value + 2
		})
		result = read()
	}
	return result
}

fn default(n int) int {
	py2v_default1 := n + 1
	read := fn (x int) int {
		return x + 3
	}
	return read(py2v_default1)
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
