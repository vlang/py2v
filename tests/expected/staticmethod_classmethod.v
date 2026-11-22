module main

pub struct MathHelper {
pub mut:
	value int
}

fn (mut self MathHelper) init(value int) {
	self.value = value
}

fn (self MathHelper) double() int {
	return py2v_integer_mul1(self.value, 2, 'staticmethod_classmethod.py:14', 'multiplication')
}

// @staticmethod
fn MathHelper.add(a int, b int) int {
	return a + b
}

// @classmethod
fn MathHelper.create(v_ int) MathHelper {
	return py2v_new_math_helper(v_)
}

pub fn py2v_new_math_helper(value int) MathHelper {
	mut py2v_instance := MathHelper{}
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
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn main() {
	result := MathHelper.add(3, 4)
	obj := MathHelper.create(10)
	println(result)
}
