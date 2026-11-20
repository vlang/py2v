module main

import pyrt

type Any = pyrt.Value

fn show_py(items Any, value ?string) ! {
	pyrt.call_method(pyrt.box(items), 'append', [pyrt.box(value)])!
	println(pyrt.str(pyrt.item_at(items, pyrt.box(-1))))
}

fn show(items Any, value ?string) {
	show_py(items, value) or { pyrt.fail(err) }
}

fn main() {
	show(pyrt.empty_list(), none)
	show(pyrt.empty_list(), '')
	show(pyrt.empty_list(), 'present')
}
