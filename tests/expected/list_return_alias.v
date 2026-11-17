module main

import pyrt

fn same(values &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	return values
}

fn main_func() {
	a := pyrt.list_ref[int]([1, 2])
	mut b := same(a)
	b.items << 3
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))}')
}

fn main() {
	main_func()
}
