module main

import pyrt

fn main() {
	a := pyrt.list_ref[int]([1, 2, 3, 4, 5, 6])
	b := a
	pyrt.list_ref_delete_slice_step(a, 0, 0, -2, false, false)
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))}')
	pyrt.list_ref_delete_slice(b, 1, 3, true, true)
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))}')
}
