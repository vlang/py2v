module main

import pyrt

type Any = pyrt.Value

pub struct Base {
pub mut:
	value string
}

fn (mut self Base) init(value string) {
	self.value = value
}

fn (self Base) greet() string {
	return 'hi ${self.value}'
}

pub fn py2v_new_base(value string) Base {
	mut py2v_instance := Base{}
	py2v_instance.init(value)
	return py2v_instance
}

pub struct Child {
	Base
}

fn (mut self Child) init(value string) {
	self.Base.init(value)
}

fn (self Child) greet() Any {
	return self.Base.greet()
}

pub fn py2v_new_child(value string) Child {
	mut py2v_instance := Child{}
	py2v_instance.init(value)
	return py2v_instance
}

pub struct CustomError {
}

fn (mut self CustomError) init(msg Any) {
	py2v_unsupported_super_init(msg)
}

pub fn py2v_new_custom_error(msg Any) CustomError {
	mut py2v_instance := CustomError{}
	py2v_instance.init(msg)
	return py2v_instance
}

fn main() {
	c := py2v_new_child('x')
	println(c.greet())
}
