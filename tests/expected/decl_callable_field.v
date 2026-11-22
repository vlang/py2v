module main

pub struct Handler {
pub mut:
	callbacks map[string]fn (int) int
	callback  fn (int) int
}

fn (mut self Handler) init(callback fn (int) int) {
	self.callback = callback
}

fn (self Handler) run(value int) int {
	return self.callback(value)
}

pub fn py2v_new_handler(callback fn (int) int) Handler {
	mut py2v_instance := Handler{}
	py2v_instance.init(callback)
	return py2v_instance
}

fn twice(value int) int {
	return py2v_integer_mul1(value, 2, 'decl_callable_field.py:16', 'multiplication')
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
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
	handler := py2v_new_handler(twice)
	println(handler.run(3))
}
