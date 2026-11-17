module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

fn outer() int {
	// WARNING: async with converted to sync with defer
	{
		py2v_unsupported_qualified_call('contextlib.AsyncExitStack')
		base := 5
		py2v_capture1 := &base
		double := fn [py2v_capture1] (x int) int {
			return (x + (*py2v_capture1)) * 2
		}
		return double(1)
	}
}

fn main() {
	println(outer())
}
