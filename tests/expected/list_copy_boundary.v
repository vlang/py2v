module main

import pyrt

fn main_func() {
	mut a := pyrt.list_ref[int]([1, 2])
	a.items[0] = 1
	mut b := a
	mut copied := pyrt.list_ref_slice[int](a, 0, 0, false, false)
	copied[0] = 9
	b.items << 3
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))} ${copied}')
	mut other := a.items.clone()
	other[0] = 8
	println('${pyrt.str(pyrt.box(a))} ${other}')
}

fn main() {
	main_func()
}
