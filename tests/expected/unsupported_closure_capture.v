module main

import pyrt

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

fn forward() int {
	read := py2v_unsupported_closure_forward_capture(fn (value int) int {
		return value + 1
	})
	value := 4
	return read()
}

fn loop() int {
	mut result := 0
	for value in []int{len: 2, init: index} {
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
