module main

import pyrt

type Any = pyrt.Value

fn append_bytes_py(items Any) ! {
	pyrt.call_method(pyrt.box(items), 'append', [pyrt.box([u8(0x41), 0x42])])!
	println(pyrt.str(pyrt.item_at(items, pyrt.box(0))))
	println(pyrt.str(pyrt.call_method(pyrt.box(pyrt.item_at(items, pyrt.box(0))), 'decode', [])!))
}

fn append_bytes(items Any) {
	append_bytes_py(items) or { pyrt.fail(err) }
}

fn main() {
	append_bytes(pyrt.empty_list())
}
