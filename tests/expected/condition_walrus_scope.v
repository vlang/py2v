module main

pub struct Gate {
pub mut:
	enabled bool
}

fn (mut self Gate) init(enabled bool) {
	self.enabled = enabled
}

fn (self Gate) ready() bool {
	println('ready')
	return self.enabled
}

fn (self Gate) show() {
	value := self.ready()
	if value {
		println(('method').str() + ' ' + (if value { 'True' } else { 'False' }).str())
	} else {
		println(('closed').str() + ' ' + (if value { 'True' } else { 'False' }).str())
	}
	println(('method-after').str() + ' ' + (if value { 'True' } else { 'False' }).str())
}

pub fn py2v_new_gate(enabled bool) Gate {
	mut py2v_instance := Gate{}
	py2v_instance.init(enabled)
	return py2v_instance
}

fn checked(value int) int {
	println('check ${value}')
	return value
}

fn yes() bool {
	println('yes')
	return true
}

fn loop_case() {
	mut saved := 0
	for i in int(0) .. int(2) {
		saved = checked(i)
		if !(saved < 0) {
			println('loop ${saved}')
		}
	}
	println('loop-after ${saved}')
}

fn nested_case() {
	mut inner := false
	outer := true
	if outer {
		inner = yes()
		if inner {
			println(('nested').str() + ' ' + (if inner { 'True' } else { 'False' }).str())
		}
	}
	println(('nested-after').str() + ' ' + (if inner { 'True' } else { 'False' }).str())
}

fn main() {
	gate := py2v_new_gate(true)
	gate.show()
	loop_case()
	nested_case()
	module_value := yes()
	if module_value {
		println(('module').str() + ' ' + (if module_value { 'True' } else { 'False' }).str())
	}
	println(('module-after').str() + ' ' + (if module_value { 'True' } else { 'False' }).str())
}
