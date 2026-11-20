module main

pub struct Limit {
pub mut:
	end int
}

fn (mut self Limit) init(end int) {
	self.end = end
}

pub fn py2v_new_limit(end int) Limit {
	mut py2v_instance := Limit{}
	py2v_instance.init(end)
	return py2v_instance
}

fn count() int {
	c := py2v_new_limit(3)
	mut i := 0
	for i < c.end {
		i += 1
	}
	return i
}

fn main() {
	println(count())
}
