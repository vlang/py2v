module main

type Any = bool | int | i64 | f64 | string | []u8

pub struct Temperature {
pub mut:
	celsius_ Any
}

fn (mut self Temperature) init(celsius f64) {
	self.celsius_ = celsius
}

fn (mut self Temperature) celsius() f64 {
	return self.celsius_
}

fn (mut self Temperature) set_celsius(value f64) {
	self.celsius_ = value
}

fn main() {
	t := Temperature{
		celsius_: 25
	}
	println(t.celsius)
	t.set_celsius(30)
	println(t.celsius)
}
