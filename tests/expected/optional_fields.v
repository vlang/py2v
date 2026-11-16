module main

pub struct BaseOptions {
pub mut:
	mobile_options ?map[string]string
	names          ?[]string
	count          ?int
}

fn (mut self BaseOptions) init() {
	self.mobile_options = none
	self.names = none
	self.count = none
}

pub fn py2v_new_base_options() BaseOptions {
	mut py2v_instance := BaseOptions{}
	py2v_instance.init()
	return py2v_instance
}
