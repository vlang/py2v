module main

type Any = bool | int | i64 | f64 | string | []u8

pub struct Base {
pub mut:
	value Any
}

fn (mut self Base) init(value Any) {
	self.value = value
}

fn (self Base) greet() Any {
	return 'hi ${self.value}'
}

pub struct Child {
	Base
}

fn (mut self Child) init(value Any) {
	self.Base.init(value)
}

fn (self Child) greet() Any {
	return self.Base.greet()
}

pub struct CustomError {
}

fn (mut self CustomError) init(msg Any) {
}

fn main() {
	c := Child{
		Base: Base{ value: 'x' }
	}
	println(c.greet())
}
