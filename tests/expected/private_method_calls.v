module main

pub struct Counter {
pub mut:
	value int
}

fn (mut self Counter) init(value int) {
	self.value = value
}

fn (self Counter) read_() int {
	return self.value
}

fn (self Counter) read() int {
	return self.read_()
}

pub fn py2v_new_counter(value int) Counter {
	mut py2v_instance := Counter{}
	py2v_instance.init(value)
	return py2v_instance
}

fn read_counter(counter Counter) int {
	if counter.read_() > 0 {
		return counter.read_()
	}
	return 0
}

fn main() {
	counter := py2v_new_counter(7)
	println(counter.read())
	println(read_counter(counter))
}
