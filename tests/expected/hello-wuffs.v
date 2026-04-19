module main

import os
import io

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
	// import ctypes: no known V equivalent
	// import ctypes: no known V equivalent
	// import pytest: use V built-in `assert` and `v test`
	// import py2many.result: no known V equivalent
	pytest.main([__file__])
	println('OK')
}
