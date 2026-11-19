module main

import os
import pyrt
import io

// TODO(py2v): no V equivalent for import ctypes, py2many.result, pytest
// Provide one in python_to_v_import (types.v) or port the module.

// TODO(py2v): no V mapping for pytest.main
// Each site below is stubbed with a zero value.

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

pub struct Py2v_parser {
pub mut:
	val u32
}

fn test_parser(input Any, expected Any) {
	mut p := Py2v_parser{
		val: u32(0)
	}
	result := p.parse(io.BytesIO(input))
	if result is Ok {
		assert pyrt.eq(result.value.value, (pyrt.getattr(pyrt.box(expected), 'value') or { pyrt.fail(err) }))
	}
}

fn main() {
	_ = Any(0)
	println('OK')
}
