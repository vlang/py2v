module py_pkg_colliding_functions

pub fn py2v_def_override_3_1(value int) int {
	return value * 2
}

pub fn py2v_def_read_4_1() int {
	return py2v_def_override_3_1(2)
}
