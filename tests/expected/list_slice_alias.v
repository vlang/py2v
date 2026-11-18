module main

import pyrt

fn replacement(py2v_values_in1 &pyrt.ListRef[int]) []int {
	mut values := unsafe { py2v_values_in1 }
	println('replacement')
	values.items << 8
	return [5, 6]
}

fn bound() int {
	println('bound')
	return 1
}

fn main_func() {
	mut a := pyrt.list_ref[int]([1, 2, 3])
	b := a
	pyrt.list_ref_assign_slice[int](replacement(a), b, bound(), 2, true, true)
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))}')
	pyrt.list_ref_assign_slice[int](pyrt.list_ref_slice[int](b, 0, 2, false, true).reverse(), b, 0, 2, false, true)
	println(pyrt.str(pyrt.box(a)))
}

fn main() {
	main_func()
}
