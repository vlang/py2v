module main

// Registry - Uses __slots__, which must not become a struct field.
pub struct Registry {
pub mut:
	count_ int
}

fn (mut self Registry) init() {
	self.count_ = 0
}

fn (mut self Registry) bump(by_ int) int {
	self.count_ = py2v_integer_add1(self.count_, by_, 'underscore_identifiers.py:17', 'addition')
	return self.count_
}

pub fn py2v_new_registry() Registry {
	mut py2v_instance := Registry{}
	py2v_instance.init()
	return py2v_instance
}

pub struct Child {
	Registry
}

fn (mut self Child) bump(by_ int) int {
	return self.Registry.bump(by_)
}

fn locals_demo() int {
	first_ := 1
	second_ := 2
	total_ := py2v_integer_add1(first_, second_, 'underscore_identifiers.py:29', 'addition')
	throwaway_, kept_ := 3, 4
	return py2v_integer_add1(total_, kept_, 'underscore_identifiers.py:31', 'addition')
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
