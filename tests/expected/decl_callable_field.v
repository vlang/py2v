module main

pub struct Handler {
pub mut:
	callbacks map[string]fn (int) int
	callback  fn (int) int
}

fn (mut self Handler) init(callback fn (int) int) {
	self.callback = callback
}

fn (self Handler) run(value int) int {
	return self.callback(value)
}

pub fn py2v_new_handler(callback fn (int) int) Handler {
	mut py2v_instance := Handler{}
	py2v_instance.init(callback)
	return py2v_instance
}

fn twice(value int) int {
	return value * 2
}

fn main() {
	handler := py2v_new_handler(twice)
	println(handler.run(3))
}
