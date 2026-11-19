module main

pub struct Counter {
pub mut:
	value int
}

fn (mut self Counter) py2v_init(value int) {
	self.value = value
}

fn (mut self Counter) init(value int) {
	self.value = value + 1
}

pub fn py2v_new_counter(value int) Counter {
	mut py2v_instance := Counter{}
	py2v_instance.py2v_init(value)
	return py2v_instance
}

fn main() {
	mut counter := py2v_new_counter(3)
	println(counter.value)
	counter.init(5)
	println(counter.value)
}
