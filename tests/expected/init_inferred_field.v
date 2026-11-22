module main

pub struct Unknown {
pub mut:
	result int
}

fn (mut self Unknown) init(value int) {
	self.result = py2v_integer_add1(value, 1, 'init_inferred_field.py:3', 'addition')
}

pub fn py2v_new_unknown(value int) Unknown {
	mut py2v_instance := Unknown{}
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
	u := py2v_new_unknown(2)
	println(u.result)
}
