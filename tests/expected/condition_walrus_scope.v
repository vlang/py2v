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
	py2v_range_start1 := 0
	py2v_range_stop2 := 2
	py2v_range_step3 := 1
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
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

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
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
