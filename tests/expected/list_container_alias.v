module main

import pyrt

fn main_func() {
	mut a := pyrt.list_ref[int]([1, 2])
	mut rows := pyrt.list_ref[&pyrt.ListRef[int]]([a])
	rows.items[0].items << 3
	println(a.items.str())
	a.items << 4
	println(rows.items[0].items.str())
	mut records := {
		'row': a
	}
	records['row'].items << 5
	println('${a.items.str()} ${rows.items[0].items.str()}')
}

fn main() {
	main_func()
}
