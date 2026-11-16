module main

pub struct Unknown {
pub mut:
	result int
}

fn (mut self Unknown) init(value int) {
	self.result = value + 1
}

pub fn py2v_new_unknown(value int) Unknown {
	mut py2v_instance := Unknown{}
	py2v_instance.init(value)
	return py2v_instance
}

fn main() {
	u := py2v_new_unknown(2)
	println(u.result)
}
