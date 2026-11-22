module main

import pyrt

type Any = pyrt.Value

fn main_func_py() ! {
	mut source := pyrt.list_ref[int]([1])
	records := map[string]Any{
		'list':  pyrt.box(source)
		'label': pyrt.box('kept')
	}
	rows := [pyrt.box(source), pyrt.box(0)]
	source.items << 2
	println((pyrt.length(records['list'])).str() + ' ' + (pyrt.length(rows[0])).str())
	pyrt.call_method(pyrt.box(records['list']), 'append', [pyrt.box(3)])!
	pyrt.call_method(pyrt.box(rows[0]), 'append', [pyrt.box(4)])!
	println(source.items.str())
	pyrt.set_index(rows[0], pyrt.box(0), pyrt.box(9))
	println(source.items.str())
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
