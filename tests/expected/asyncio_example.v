module main

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

fn nested() int {
	return 42
}

fn async_main() {
	assert nested() == 42
	println('OK')
}

fn main() {
	async_main()
}
