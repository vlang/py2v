module main

import pyrt

fn main_func() {
	values := pyrt.list_ref[int]([1, 2, 3])
	alias := values
	pyrt.list_ref_assign_slice_step[int]([8, 9], values, 1, 2, 1, true, true)
	println('${pyrt.str(pyrt.box(values))} ${pyrt.str(pyrt.box(alias))}')
	pyrt.list_ref_assign_slice_step[int]([], values, 0, 1, 1, false, true)
	println('${pyrt.str(pyrt.box(values))} ${pyrt.str(pyrt.box(alias))}')
	pyrt.list_ref_assign_slice_step[int]([4, 5], values, 0, 0, 1, false, false)
	println('${pyrt.str(pyrt.box(values))} ${pyrt.str(pyrt.box(alias))}')
	pyrt.list_ref_assign_slice_step[int]([7], values, 1, 0, 1, true, true)
	println('${pyrt.str(pyrt.box(values))} ${pyrt.str(pyrt.box(alias))}')
}

fn main() {
	main_func()
}
