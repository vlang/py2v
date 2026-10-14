module main

import os
import io

// TODO(py2v): no V equivalent for import ctypes, py2many.result, pytest
// Provide one in python_to_v_import (types.v) or port the module.

// TODO(py2v): no V mapping for pytest.main
// Each site below is stubbed with a zero value.

type Any = bool | int | i64 | f64 | string | []u8

pub struct parser {
pub mut:
	val u32
}

fn test_parser(input Any, expected Any) {
	p := parser{
		val: u32(0)
	}
	result := p.parse(io.BytesIO(input))
	if result is Ok {
		assert result.value.value == expected.value
	}
}

fn main() {
	Any(0)
	println('OK')
}
