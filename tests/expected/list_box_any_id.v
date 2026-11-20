module main

import pyrt

type Any = pyrt.Value

fn inspect(v_ Any) {
	println((if pyrt.eq(pyrt.box(v_), pyrt.box(v_)) { 'True' } else { 'False' }).str() + ' ' + (if pyrt.same_object(pyrt.box(v_), pyrt.box(v_)) {
		'True'
	} else {
		'False'
	}).str())
}

fn main() {
	a := pyrt.list_ref[int]([1])
	b := a
	inspect(pyrt.box(a))
	println(b.items.str())
}
