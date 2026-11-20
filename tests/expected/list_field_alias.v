module main

import pyrt

pub struct Holder {
pub mut:
	values &pyrt.ListRef[int] = &pyrt.ListRef[int]{}
}

fn (mut self Holder) init(values &pyrt.ListRef[int]) {
	self.values = values
}

fn (mut self Holder) add(value int) {
	self.values.items << value
}

pub fn py2v_new_holder(values &pyrt.ListRef[int]) Holder {
	mut py2v_instance := Holder{}
	py2v_instance.init(values)
	return py2v_instance
}

fn main_func() {
	mut a := pyrt.list_ref[int]([1, 2])
	mut holder := py2v_new_holder(a)
	holder.add(3)
	println('${a.items.str()} ${pyrt.str(pyrt.box(holder.values))}')
	a.items << 4
	println(pyrt.str(pyrt.box(holder.values)))
}

fn main() {
	main_func()
}
