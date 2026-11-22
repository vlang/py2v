module main

import pyrt

// TODO(py2v): no V equivalent for import asyncio
// Provide one in python_to_v_import (types.v) or port the module.

type Any = pyrt.Value

pub struct Runner {
}

fn (self Runner) wait(future Any) int {
	panic('py2v_unsupported_coroutine: wait requires an awaitable with unknown scheduling')
}

fn answer() int {
	return 7
}

fn read_future(loop Any) int {
	panic('py2v_unsupported_coroutine: read_future requires asyncio.run_coroutine_threadsafe')
}

fn supported() int {
	return 42
}

fn annotation_only(value Any) int {
	return 9
}

fn main() {
	println(supported())
	println(annotation_only(pyrt.none_))
}
