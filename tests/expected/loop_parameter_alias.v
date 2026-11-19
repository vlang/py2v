module main

pub struct Box {
pub mut:
	value int
}

fn (mut self Box) init(value int) {
	self.value = value
}

pub fn py2v_new_box(value int) Box {
	mut py2v_instance := Box{}
	py2v_instance.init(value)
	return py2v_instance
}

fn rebind_box(mut value Box) int {
	mut py2v_param_rebind1 := value
	for value_ in [py2v_new_box(3), py2v_new_box(4)] {
		py2v_param_rebind1 = value_
		break
	}
	return 0
}

fn mutate_then_rebind(mut value Box) int {
	value.value = 9
	mut py2v_param_rebind2 := value
	for value_ in [py2v_new_box(3)] {
		py2v_param_rebind2 = value_
		// pass
	}
	return 0
}

fn rebind_list(py2v_value_in3 []int) int {
	mut value := py2v_value_in3
	for value_ in [[3, 4]] {
		value = unsafe { value_ }
		// pass
	}
	return 0
}

fn run() {
	mut original := py2v_new_box(7)
	mut items := [7, 8]
	rebind_box(mut original)
	rebind_list(items)
	println(original.value)
	println(items[0])
	mut second := py2v_new_box(7)
	mutate_then_rebind(mut second)
	println(second.value)
}

fn main() {
	run()
}
