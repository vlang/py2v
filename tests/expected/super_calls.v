module main

type Any = bool | int | i64 | f64 | string | []u8

pub struct Base {
pub mut:
	value string
}

fn (mut self Base) init(value string) {
	self.value = value
}

fn (self Base) greet() Any {
	return 'hi ${self.value}'
}

pub struct Child {
	Base
}

fn (mut self Child) init(value string) {
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
