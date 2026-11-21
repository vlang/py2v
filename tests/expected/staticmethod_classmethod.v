module main

pub struct MathHelper {
pub mut:
	value int
}

fn (mut self MathHelper) init(value int) {
	self.value = value
}

fn (self MathHelper) double() int {
	return self.value * 2
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

fn main() {
	result := MathHelper.add(3, 4)
	obj := MathHelper.create(10)
	println(result)
}
