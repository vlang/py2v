module main

import pyrt

fn main_func() {
	a := pyrt.list_ref[int]([1, 2, 3])
	mut b := a
	b.items.delete(1)
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))}')
}

fn main() {
	main_func()
}
