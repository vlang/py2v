module main

import pyrt

fn main() {
	a := pyrt.list_ref[int]([1, 2, 3, 4])
	b := a
	pyrt.list_ref_delete_slice(a, 1, 3, true, true)
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))}')
}
