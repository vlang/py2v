module main

pub struct Box {
pub mut:
	value int
}

fn (mut self Box) py2v_overload_1_init(value int) {
	// ...
	panic('typing.overload stub is not callable')
}

fn (mut self Box) init(value int) {
	self.value = value
}

fn (self Box) py2v_overload_2_add(other Box) Box {
	// ...
	panic('typing.overload stub is not callable')
}

fn (self Box) py2v_overload_3_add(other int) Box {
	// ...
	panic('typing.overload stub is not callable')
}

fn (self Box) + (other Box) Box {
	return py2v_new_box(self.value + other.value)
}

fn (self Box) py2v_overload_4_fetch(index int) int {
	// ...
	panic('typing.overload stub is not callable')
}

fn (self Box) py2v_overload_5_fetch(index string) int {
	// ...
	panic('typing.overload stub is not callable')
}

fn (self Box) fetch(index int) int {
	return self.value + index
}

pub fn py2v_new_box(value int) Box {
	mut py2v_instance := Box{}
	py2v_instance.init(value)
	return py2v_instance
}

fn main() {
	box := py2v_new_box(2)
	println(box.fetch(3))
	println((box + py2v_new_box(4)).value)
}
