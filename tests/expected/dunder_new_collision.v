module main

pub struct Item {
}

fn (self Item) py2v_dunder_new(cls int, value int) int {
	return py2v_integer_add1(value, 2, 'dunder_new_collision.py:3', 'addition')
}

fn (self Item) new(value int) int {
	return py2v_integer_add1(value, 1, 'dunder_new_collision.py:6', 'addition')
}

fn call_new(item Item, value int) int {
	return item.new(value)
}

fn call_allocator(item Item, value int) int {
	return item.py2v_dunder_new(0, value)
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
	println('loaded')
}
