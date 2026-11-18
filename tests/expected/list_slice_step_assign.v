module main

import pyrt

fn main() {
	a := pyrt.list_ref[int]([1, 2, 3, 4, 5])
	b := a
	pyrt.list_ref_assign_slice_step[int]([9, 8, 7], b, 0, 0, 2, false, false)
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))}')
	pyrt.list_ref_assign_slice_step[int]([6, 4, 2], b, 0, 0, -2, false, false)
	println(pyrt.str(pyrt.box(a)))
}
