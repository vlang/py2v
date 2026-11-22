module main

pub struct Limit {
pub mut:
	end int
}

fn (mut self Limit) init(end int) {
	self.end = end
}

pub fn py2v_new_limit(end int) Limit {
	mut py2v_instance := Limit{}
	py2v_instance.init(end)
	return py2v_instance
}

fn count() int {
	c := py2v_new_limit(3)
	mut i := 0
	for i < c.end {
		i = py2v_integer_add1(i, 1, 'uppercase_condition.py:10', 'addition')
	}
	return i
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
	println(count())
}
