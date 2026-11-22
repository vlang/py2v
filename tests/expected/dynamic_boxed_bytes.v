module main

import pyrt

type Any = pyrt.Value

fn append_bytes_py(items Any) ! {
	pyrt.call_method(pyrt.box(items), 'append', [pyrt.box([u8(0x41), 0x42])])!
	println(pyrt.str(pyrt.item_at(items, pyrt.box(0))))
	println(pyrt.str(pyrt.call_method(pyrt.box(pyrt.item_at(items, pyrt.box(0))), 'decode', [])!))
}

fn py2v_entry1() ! {
	append_bytes_py(pyrt.empty_list())!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
