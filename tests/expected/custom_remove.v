module main

pub struct Leaf {
pub mut:
	value int
}

fn (mut self Leaf) init(value int) {
	self.value = value
}

fn (mut self Leaf) remove() int {
	self.value = py2v_integer_add1(self.value, 1, 'custom_remove.py:6', 'addition')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	main_func()
}
