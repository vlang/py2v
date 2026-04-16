@[translated]

module main

pub struct Temperature {
pub mut:
	_celsius Any
}

fn (mut self Temperature) __init__(celsius f64) {
	self._celsius = celsius
}

fn (self Temperature) celsius() f64 {
	return self._celsius
}

fn (mut self Temperature) set_celsius(value f64) {
	self._celsius = value
}

fn main() {
	t := Temperature{
		_celsius: 25
	}
	println(t.celsius)
	t.set_celsius(30)
	println(t.celsius)
}

type Any = bool | int | i64 | f64 | string | []u8
