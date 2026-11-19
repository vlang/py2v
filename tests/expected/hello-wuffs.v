module main

import os
import pyrt

// TODO(py2v): no V equivalent for import ctypes, py2many.result, pytest
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

pub struct Py2v_parser {
pub mut:
	val u32
}

fn test_parser(input Any, expected Any) {
	panic('py2v_unsupported_coroutine: test_parser requires an awaitable with unknown scheduling')
}

fn main() {
	(pyrt.untranslated_import('pytest.main') or { pyrt.fail(err) })
	println('OK')
}
