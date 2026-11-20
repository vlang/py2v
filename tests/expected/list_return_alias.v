module main

import pyrt

fn same(values &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	return values
}

fn main_func() {
	a := pyrt.list_ref[int]([1, 2])
	mut b := same(a)
	b.items << 3
	println('${a.items.str()} ${b.items.str()}')
}

fn main() {
	main_func()
}
