@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

pub struct Base {
pub mut:
	value Any
}

fn (mut self Base) __init__(value Any) {
	self.value = value
}

fn (self Base) greet() {
	return 'hi ' + (self.value).str()
}

pub struct Child {
	Base
}

fn (mut self Child) __init__(value Any) {
	self.Base.__init__(value)
}

fn (self Child) greet() {
	return self.Base.greet()
}

pub struct CustomError {
}

fn (mut self CustomError) __init__(msg Any) {
}

fn main() {
	c := Child{
		Base: Base{
			value: 'x'
		}
	}
	println((c.greet()).str())
}
