module main

import pyrt

fn main_func() {
	mut a := pyrt.list_ref[int]([1, 2])
	mut b := a
	b.items << 3
	println('${a.items.str()} ${b.items.str()}')
	a = pyrt.list_ref[int]([9])
	b.items << 4
	println('${a.items.str()} ${b.items.str()}')
	b.items[0] = 7
	mut c := b
	c.items.pop()
	println('${b.items.str()} ${c.items.str()}')
}

fn main() {
	main_func()
}
