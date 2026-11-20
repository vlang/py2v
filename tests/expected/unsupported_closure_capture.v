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
			return value + 2
		})
		result = read()
	}
	return result
}

fn default(n int) int {
	py2v_default4 := n + 1
	read := fn (x int) int {
		return x + 3
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
