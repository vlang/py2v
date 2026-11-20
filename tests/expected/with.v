module main

import pyrt

type Any = pyrt.Value

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
	{
		f := py2v_new_mock_file('test.txt')
		println(f.read())
	}
}

fn main() {
	show()
}
