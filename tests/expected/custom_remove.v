module main

pub struct Leaf {
pub mut:
	value int
}

fn (mut self Leaf) init(value int) {
	self.value = value
}

fn (mut self Leaf) remove() int {
	self.value += 1
	return self.value
}

pub fn py2v_new_leaf(value int) Leaf {
	mut py2v_instance := Leaf{}
	py2v_instance.init(value)
	return py2v_instance
}

fn main_func() {
	mut leaf := py2v_new_leaf(3)
	first := leaf.remove()
	leaf.remove()
	println(first)
	println(leaf.value)
}

fn main() {
	main_func()
}
