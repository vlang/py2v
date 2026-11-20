module main

import pyrt

fn edit(a &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	pyrt.list_ref_assign_slice[int]([5, 6], a, 0, 1, true, true)
	return a
}

fn main() {
	x := pyrt.list_ref[int]([1, 2, 3])
	println(pyrt.str(pyrt.box(edit(x))))
	println(pyrt.str(pyrt.box(x)))
}
