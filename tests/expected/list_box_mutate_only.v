module main

import pyrt

type Any = pyrt.Value

fn main_func_py() ! {
	source := pyrt.list_ref[int]([1])
	mut rows := []Any{}
	rows << 0
	rows << pyrt.box(source)
	pyrt.call_method(pyrt.box(rows[1]), 'append', [pyrt.box(2)])!
	println(source.items.str())
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
