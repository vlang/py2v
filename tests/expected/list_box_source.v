module main

import pyrt

type Any = pyrt.Value

fn main_func_py() ! {
	mut source := pyrt.list_ref[int]([1])
	mut rows := []Any{}
	rows << 0
	rows << pyrt.box(source)
	rows << pyrt.box(source)
	source.items << 2
	println('${pyrt.length(rows[1])} ${pyrt.length(rows[2])}')
	pyrt.call_method(pyrt.box(rows[1]), 'append', [pyrt.box(3)])!
	println(source.items.str())
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
