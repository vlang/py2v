module main

pub struct Counter {
pub mut:
	value int
}

fn (mut self Counter) py2v_init(value int) {
	self.value = value
}

fn (mut self Counter) init(value int) {
	self.value = py2v_integer_add1(value, 1, 'decl_duplicate_init.py:6', 'addition')
}

pub fn py2v_new_counter(value int) Counter {
	mut py2v_instance := Counter{}
	py2v_instance.py2v_init(value)
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
	mut counter := py2v_new_counter(3)
	println(counter.value)
	counter.init(5)
	println(counter.value)
}
