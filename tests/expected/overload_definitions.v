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
	return py2v_new_box(py2v_integer_add1(self.value, other.value, 'overload_definitions.py:20', 'addition'))
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
	return py2v_integer_add1(self.value, index, 'overload_definitions.py:29', 'addition')
}

pub fn py2v_new_box(value int) Box {
	mut py2v_instance := Box{}
	py2v_instance.init(value)
	return py2v_instance
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
	box := py2v_new_box(2)
	println(box.fetch(3))
	println((box + py2v_new_box(4)).value)
}
