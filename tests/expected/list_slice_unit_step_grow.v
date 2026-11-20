module main

import pyrt

fn main_func() {
	values := pyrt.list_ref[int]([1, 2, 3])
	alias := values
	pyrt.list_ref_assign_slice_step[int]([8, 9], values, 1, 2, 1, true, true)
	println('${values.items.str()} ${alias.items.str()}')
	pyrt.list_ref_assign_slice_step[int]([7], values, 1, 1, 1, true, true)
	println('${values.items.str()} ${alias.items.str()}')
}

fn main() {
	main_func()
}
