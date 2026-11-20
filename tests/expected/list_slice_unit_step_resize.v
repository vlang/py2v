module main

import pyrt

fn main_func() {
	values := pyrt.list_ref[int]([1, 2, 3])
	alias := values
	pyrt.list_ref_assign_slice_step[int]([8, 9], values, 1, 2, 1, true, true)
	println('${values.items.str()} ${alias.items.str()}')
	pyrt.list_ref_assign_slice_step[int]([], values, 0, 1, 1, false, true)
	println('${values.items.str()} ${alias.items.str()}')
	pyrt.list_ref_assign_slice_step[int]([4, 5], values, 0, 0, 1, false, false)
	println('${values.items.str()} ${alias.items.str()}')
	pyrt.list_ref_assign_slice_step[int]([7], values, 1, 0, 1, true, true)
	println('${values.items.str()} ${alias.items.str()}')
}

fn main() {
	main_func()
}
