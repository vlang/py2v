module main

pub struct Thing {
pub mut:
	x int
}

fn (mut self Thing) init(x int) {
	self.x = x
}

pub fn py2v_new_thing(x int) Thing {
	mut py2v_instance := Thing{}
	py2v_instance.init(x)
	return py2v_instance
}

fn main() {
	t := py2v_new_thing(1)
	println(t.x)
}
