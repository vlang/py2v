module main

pub struct Box {
pub mut:
	value_ int
}

fn (mut self Box) init() {
	self.value_ = 0
}

fn (self Box) value() int {
	return self.value_
}

fn (mut self Box) py2v_property_setter_value(assigned int) {
	self.set_value(py2v_integer_add1(assigned, 1, 'property_accessor_collision.py:11', 'addition'))
}

fn (mut self Box) py2v_property_deleter_value() {
	self.value_ = -1
}

fn (mut self Box) set_value(assigned int) {
	self.value_ = py2v_integer_mul1(2, assigned, 'property_accessor_collision.py:18', 'multiplication')
}

pub fn py2v_new_box() Box {
	mut py2v_instance := Box{}
	py2v_instance.init()
	return py2v_instance
}

fn assigned_value() int {
	println('assign')
	return 3
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

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn main() {
	mut box := py2v_new_box()
	py2v_property_value_1 := assigned_value()
	box.py2v_property_setter_value(py2v_property_value_1)
	println(box.value())
	box.set_value(5)
	println(box.value())
	box.py2v_property_deleter_value()
	println(box.value())
}
