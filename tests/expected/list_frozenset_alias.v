module main

import pyrt

fn main() {
	a := pyrt.list_ref[int]([1, 2])
	mut b := a
	frozen := (pyrt.frozenset_from(pyrt.box(pyrt.box(a))) or { pyrt.fail(err) })
	b.items << 3
	println((pyrt.length(frozen)).str() + ' ' + (pyrt.str((pyrt.item_in(pyrt.box(pyrt.box(1)), pyrt.box(frozen)) or { pyrt.fail(err) }))).str())
	println((pyrt.str(pyrt.box(a))).str() + ' ' + (pyrt.str(pyrt.box(b))).str() + ' ' + (if pyrt.object_identity(pyrt.box(a)) == pyrt.object_identity(pyrt.box(b)) {
		'True'
	} else {
		'False'
	}).str())
}
