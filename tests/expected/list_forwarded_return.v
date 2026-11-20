module main

import pyrt

fn edit(py2v_values_in1 &pyrt.ListRef[int]) &pyrt.ListRef[int] {
	mut values := unsafe { py2v_values_in1 }
	copy_second(values)
	return values
}

fn copy_second(py2v_values_in2 &pyrt.ListRef[int]) {
	mut values := unsafe { py2v_values_in2 }
	values.items[0] = values.items[1]
}

fn main() {
	mut items := pyrt.list_ref[int]([1, 2])
	println(pyrt.str(pyrt.box(edit(items))))
	println(pyrt.str(pyrt.box(items)))
}
