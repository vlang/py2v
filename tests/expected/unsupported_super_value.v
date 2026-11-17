module main

import pyrt

// TODO(py2v): no V equivalent for import outside
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

pub struct Child {
}

fn (self Child) value(x int) Any {
	result := py2v_unsupported_super_make(x, 3)
	return result
}

fn (self Child) stream(ch chan Any) {
	defer { ch.close() }
	py2v_gen1 := py2v_unsupported_super_stream()
	// yield from py2v_gen1
	for {
		val := <-py2v_gen1 or { break }
		ch <- val
	}
}
