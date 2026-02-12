@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

pub struct MockFile {
pub mut:
	name   Any
	closed Any
}

fn (mut self MockFile) __init__(name Any) {
	self.name = name
	self.closed = false
}

fn (self MockFile) __enter__() {
	println(('Opening ' + (self.name).str()).str())
	return self
}

fn (mut self MockFile) __exit__(exc_type Any, exc_val Any, exc_tb Any) bool {
	println(('Closing ' + (self.name).str()).str())
	self.closed = true
	return false
}

fn (self MockFile) read() string {
	return 'content'
}

fn show() {
	if true {
		f := MockFile{
			name: 'test.txt'
		}
		println(f.read())
	}
}

fn main() {
	show()
}
