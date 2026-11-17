module main

import math

pub struct Counter {
pub mut:
	value int
}

fn (mut self Counter) init(value int) {
	self.value = value
}

pub fn py2v_new_counter(value int) Counter {
	mut py2v_instance := Counter{}
	py2v_instance.init(value)
	return py2v_instance
}

fn index() int {
	println('index')
	return 0
}

fn divisor() int {
	println('divisor')
	return 3
}

fn main_func() {
	mut values := [-7]
	mut py2v_container1 := &values
	py2v_index2 := index()
	py2v_old3 := (*py2v_container1)[if py2v_index2 < 0 {
		py2v_container1.len + py2v_index2
	} else {
		py2v_index2
	}]
	(*py2v_container1)[if py2v_index2 < 0 { py2v_container1.len + py2v_index2 } else { py2v_index2 }] = math.modulo_floored(py2v_old3, divisor())
	println(values)
	mut obj := py2v_new_counter(-7)
	mut py2v_receiver4 := &obj
	py2v_old5 := py2v_receiver4.value
	py2v_receiver4.value = math.modulo_floored(py2v_old5, divisor())
	println(obj.value)
}

fn main() {
	main_func()
}
