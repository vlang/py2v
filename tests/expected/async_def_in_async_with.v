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
			return py2v_integer_mul1(int(x + (*py2v_capture1)), 2, 'async_def_in_async_with.py:10', 'multiplication')
		}
		return double(1)
	}
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn main() {
	println(outer())
}
