module main

import pyrt

// TODO(py2v): no V equivalent for import outside
// Provide one in python_to_v_import (types.v) or port the module.

type Any = pyrt.Value

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
