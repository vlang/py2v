module main

import pyrt

fn main() {
	mut a := pyrt.list_ref[int]([3, 1, 2])
	b := a
	for x in b.items {
		if x == 1 {
			a.items.sort(a < b)
		}
		println(x)
	}
	println(pyrt.str(pyrt.box(a)))
}
