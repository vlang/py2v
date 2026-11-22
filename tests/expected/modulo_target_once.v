module main

pub struct Counter {
pub mut:
	value int
}

fn (mut self Counter) init(value int) {
	self.value = value
}

pub fn py2v_new_counter(value int) Counter {
	mut py2v_instance := Counter{}
	py2v_instance.init(value)
	return py2v_instance
}

fn index() int {
	println('index')
	return 0
}

fn divisor() int {
	println('divisor')
	return 3
}

fn main_func() {
	mut values := [-7]
	mut py2v_container1 := &values
	py2v_index2 := index()
	py2v_old3 := (*py2v_container1)[if py2v_index2 < 0 {
		py2v_container1.len + py2v_index2
	} else {
		py2v_index2
	}]
	py2v_aug_result4 := py2v_integer_mod1(py2v_old3, divisor(), 'modulo_target_once.py:20')
	(*py2v_container1)[if py2v_index2 < 0 { py2v_container1.len + py2v_index2 } else { py2v_index2 }] = py2v_aug_result4
	println(values)
	mut obj := py2v_new_counter(-7)
	mut py2v_receiver5 := &obj
	py2v_old6 := py2v_receiver5.value
	py2v_aug_result7 := py2v_integer_mod1(py2v_old6, divisor(), 'modulo_target_once.py:23')
	py2v_receiver5.value = py2v_aug_result7
	println(obj.value)
}

@[inline]
fn py2v_integer_mod1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer modulo by zero') }
	if b == -1 { return 0 }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return if adjust { r + b } else { r }
}

fn main() {
	main_func()
}
