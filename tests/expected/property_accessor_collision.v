module main

pub struct Box {
pub mut:
	value_ int
}

fn (mut self Box) init() {
	self.value_ = 0
}

fn (self Box) value() int {
	return self.value_
}

fn (mut self Box) py2v_property_setter_value(assigned int) {
	self.set_value(assigned + 1)
}

fn (mut self Box) py2v_property_deleter_value() {
	self.value_ = -1
}

fn (mut self Box) set_value(assigned int) {
	self.value_ = 2 * assigned
}

pub fn py2v_new_box() Box {
	mut py2v_instance := Box{}
	py2v_instance.init()
	return py2v_instance
}

fn assigned_value() int {
	println('assign')
	return 3
}

fn main() {
	mut box := py2v_new_box()
	py2v_property_value_1 := assigned_value()
	box.py2v_property_setter_value(py2v_property_value_1)
	println(box.value())
	box.set_value(5)
	println(box.value())
	box.py2v_property_deleter_value()
	println(box.value())
}
