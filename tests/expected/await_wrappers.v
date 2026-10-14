module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

fn nested() int {
	return 7
}

fn show() {
	a := nested()
	b := nested()
	assert a == 7
	assert b == 7
}

fn main() {
	show()
}
