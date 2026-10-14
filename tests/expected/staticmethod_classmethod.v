module main

type Any = bool | int | i64 | f64 | string | []u8

pub struct MathHelper {
pub mut:
	value Any
}

fn (mut self MathHelper) init(value int) {
	self.value = value
}

fn (self MathHelper) double() int {
	return self.value * 2
}

// @staticmethod
fn MathHelper_add(a int, b int) int {
	return a + b
}

// @classmethod
fn MathHelper_create(v_ int) MathHelper {
	return MathHelper{
		value: v_
	}
}

fn main() {
	result := MathHelper.add(3, 4)
	obj := MathHelper.create(10)
	println(result)
}
