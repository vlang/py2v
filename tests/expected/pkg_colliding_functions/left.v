module py_pkg_colliding_functions

pub fn py2v_def_override_1_1(value int) int {
	return value + 1
}

pub fn keep_local(override int) int {
	return override
}

pub fn py2v_def_read_2_1() int {
	return keep_local(py2v_def_override_1_1(2))
}
