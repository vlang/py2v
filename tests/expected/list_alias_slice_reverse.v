module main

import pyrt

fn main() {
	a := pyrt.list_ref[int]([1, 2, 3, 4])
	mut b := a
	println(pyrt.list_ref_slice_step(a, 0, 0, -1, false, false))
	println(pyrt.list_ref_slice_step(a, 0, 0, 2, false, false))
	b.items << 5
	println(pyrt.str(pyrt.box(a)))
}
