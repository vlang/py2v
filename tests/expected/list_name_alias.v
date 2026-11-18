module main

import pyrt

fn main_func() {
	mut a := pyrt.list_ref[int]([1, 2])
	mut b := a
	b.items << 3
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))}')
	a = pyrt.list_ref[int]([9])
	b.items << 4
	println('${pyrt.str(pyrt.box(a))} ${pyrt.str(pyrt.box(b))}')
	b.items[0] = 7
	mut c := b
	c.items.pop()
	println('${pyrt.str(pyrt.box(b))} ${pyrt.str(pyrt.box(c))}')
}

fn main() {
	main_func()
}
