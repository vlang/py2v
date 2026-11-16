module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

pub struct MockFile {
pub mut:
	name   string
	closed bool
}

fn (mut self MockFile) init(name string) {
	self.name = name
	self.closed = false
}

fn (self MockFile) enter() Any {
	println('Opening ${self.name}')
	return self
}

fn (mut self MockFile) exit(exc_type Any, exc_val Any, exc_tb Any) bool {
	println('Closing ${self.name}')
	self.closed = true
	return false
}

fn (self MockFile) read() string {
	return 'content'
}

pub fn py2v_new_mock_file(name string) MockFile {
	mut py2v_instance := MockFile{}
	py2v_instance.init(name)
	return py2v_instance
}

fn show() {
	if true {
		f := py2v_new_mock_file('test.txt')
		println(f.read())
	}
}

fn main() {
	show()
}
