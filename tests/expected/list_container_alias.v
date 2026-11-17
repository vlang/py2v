module main

import pyrt

fn main_func() {
	mut a := pyrt.list_ref[int]([1, 2])
	mut rows := pyrt.list_ref[&pyrt.ListRef[int]]([a])
	rows.items[0].items << 3
	println(pyrt.str(pyrt.box(a)))
	a.items << 4
	println(pyrt.str(pyrt.box(rows.items[0])))
	mut records := {
		'row': a
	}
	records['row'].items << 5
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(rows.items[0]))}')
}

fn main() {
	main_func()
}
