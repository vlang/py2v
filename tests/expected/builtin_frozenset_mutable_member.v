module main

import pyrt

fn show_py() ! {
	inner := pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(1)])))!
	outer := pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(inner)])))!
	println(pyrt.str(pyrt.item_in(pyrt.box(pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(1)])))!), pyrt.box(outer))!))
	println(pyrt.str(pyrt.item_in(pyrt.box(pyrt.Value(pyrt.new_set([pyrt.box(1)])!)), pyrt.box(outer))!))
	println(pyrt.str(pyrt.item_in(pyrt.box(pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(2)])))!), pyrt.box(outer))!))
}

fn show() {
	show_py() or { pyrt.fail(err) }
}

fn main() {
	show()
}
