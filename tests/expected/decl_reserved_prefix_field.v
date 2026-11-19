module main

pub struct C_struct {
pub mut:
	py2v_dunder_py2v_dunder_payload int
}

fn (mut self C_struct) init(py2v_dunder_py2v_dunder_payload int) {
	self.py2v_dunder_py2v_dunder_payload = py2v_dunder_py2v_dunder_payload
}

fn (self C_struct) get() int {
	return self.py2v_dunder_py2v_dunder_payload
}

pub fn py2v_new_c_struct(py2v_dunder_py2v_dunder_payload int) C_struct {
	mut py2v_instance := C_struct{}
	py2v_instance.init(py2v_dunder_py2v_dunder_payload)
	return py2v_instance
}

fn main() {
	println(py2v_new_c_struct(7).get())
}
