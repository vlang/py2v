module main

pub struct Temperature {
pub mut:
	celsius_ f64
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

pub fn py2v_new_temperature(celsius f64) Temperature {
	mut py2v_instance := Temperature{}
	py2v_instance.init(celsius)
	return py2v_instance
}

fn main() {
	t := py2v_new_temperature(25)
	println(t.celsius)
	t.set_celsius(30)
	println(t.celsius)
}
