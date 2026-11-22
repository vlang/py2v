module main

pub struct Counter {
pub mut:
	total int
}

fn (mut self Counter) init() {
	self.total = 1
}

fn (mut self Counter) grow() {
	for i in int(0) .. int(5) {
		self.total = py2v_integer_add1(self.total, self.total, 'checked_growth_storage.py:7', 'addition')
	}
}

pub fn py2v_new_counter() Counter {
	mut py2v_instance := Counter{}
	py2v_instance.init()
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
	mut item := py2v_new_counter()
	item.grow()
	println(item.total)
	mut values := [1]
	for i in int(0) .. int(5) {
		values[0] = py2v_integer_add1(values[0], values[0], 'checked_growth_storage.py:16', 'addition')
	}
	println(values[0])
}
