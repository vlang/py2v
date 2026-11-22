module py_pkg_colliding_functions

pub fn py2v_def_override_3_1(value int) int {
	return py2v_integer_mul1(value, 2, 'right.py:7', 'multiplication')
}

pub fn py2v_def_read_4_1() int {
	return py2v_def_override_3_1(2)
}
