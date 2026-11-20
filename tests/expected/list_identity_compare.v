module main

import pyrt

fn main_func() {
	a := pyrt.list_ref[int]([1])
	mut b := a
	c := pyrt.list_ref[int]([1])
	println((if pyrt.object_identity(pyrt.box(a)) == pyrt.object_identity(pyrt.box(b)) {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if pyrt.object_identity(pyrt.box(a)) == pyrt.object_identity(pyrt.box(c)) {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if a.items == c.items { 'True' } else { 'False' }).str())
	b.items << 2
	println('${a.items.str()} ${c.items.str()}')
	x := pyrt.list_ref[&pyrt.ListRef[int]]([a])
	y := [[1, 2]]
	println(if pyrt.eq(pyrt.box(x), pyrt.box(y)) { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
