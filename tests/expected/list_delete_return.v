module main

import pyrt

fn edit(py2v_a_in1 &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	mut a := unsafe { py2v_a_in1 }
	a.items.delete(0)
	return a
}

fn check() {
	mut x := pyrt.list_ref[int]([1, 2])
	println(edit(x).items.str())
	println(x.items.str())
}

fn main() {
	check()
}
