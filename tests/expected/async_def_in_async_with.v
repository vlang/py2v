module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

fn double(x int) int {
	return (x + base) * 2
}

fn outer() int {
	// WARNING: async with converted to sync with defer
	if true {
		contextlib.AsyncExitStack()
		base := 5
		// pass
		return double(1)
	}
}

fn main() {
	println(outer())
}
