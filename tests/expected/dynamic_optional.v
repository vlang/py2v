module main

import pyrt

type Any = pyrt.Value

fn show_py(items Any, value ?string) ! {
	pyrt.call_method(pyrt.box(items), 'append', [pyrt.box(value)])!
	println(pyrt.str(pyrt.item_at(items, pyrt.box(-1))))
}

fn py2v_entry1() ! {
	show_py(pyrt.empty_list(), none)!
	show_py(pyrt.empty_list(), '')!
	show_py(pyrt.empty_list(), 'present')!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
