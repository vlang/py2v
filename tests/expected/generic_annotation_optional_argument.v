module main

import pyrt

// TODO(py2v): no V equivalent for import contextvars
// Provide one in python_to_v_import (types.v) or port the module.

// TODO(py2v): no V mapping for contextvars.ContextVar
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

fn bind(value string) Token[?string] {
	return var.set(value)
}

fn main() {
	var := Any(0)
	bind('x')
	println(var.get())
}
