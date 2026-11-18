module main

// TODO(py2v): no V equivalent for import contextvars
// Provide one in python_to_v_import (types.v) or port the module.

fn bind(value string) Token[?string] {
	return var.set(value)
}

fn main() {
	var := py2v_unsupported_qualified_call('contextvars.ContextVar', 'v', 'default', none)
	bind('x')
	println(var.get())
}
