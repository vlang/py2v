module main

pub struct C_struct {
pub mut:
	py2v_numeric_py2v_numeric_marker int
}

fn (mut self C_struct) init(py2v_numeric_py2v_numeric_marker int) {
	self.py2v_numeric_py2v_numeric_marker = py2v_numeric_py2v_numeric_marker
}

fn (self C_struct) get() int {
	return self.py2v_numeric_py2v_numeric_marker
}

pub fn py2v_new_c_struct(py2v_numeric_py2v_numeric_marker int) C_struct {
	mut py2v_instance := C_struct{}
	py2v_instance.init(py2v_numeric_py2v_numeric_marker)
	return py2v_instance
}

fn main() {
	println(py2v_new_c_struct(17).get())
}
