module main

import pyrt

// TODO(py2v): no V equivalent for import unavailable
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

fn compute(value int) int {
	println(value)
	return value
}

fn construct() Any {
	return py2v_unsupported_qualified_call('external.Widget', compute(1), compute(2), 'mode', compute(3))
}

fn method_py(receiver Any) !Any {
	return pyrt.call(pyrt.getattr(pyrt.box(receiver), 'Upper')!, [
		pyrt.box(compute(4)),
		pyrt.box(compute(5)),
	])!
}

fn method(receiver Any) Any {
	return method_py(receiver) or { pyrt.fail(err) }
}
