@[translated]
module main

pub struct BaseOptions {
pub mut:
	mobile_options ?map[string]string
	names ?[]string
	count ?int
}

fn (mut self BaseOptions) __init__() {
	self.mobile_options = none
	self.names = none
	self.count = none
}
