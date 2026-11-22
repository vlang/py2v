module py_pkg_colliding_functions

pub fn py2v_def_override_1_1(value int) int {
	return py2v_integer_add1(value, 1, 'left.py:7', 'addition')
}

pub fn keep_local(override int) int {
	return override
}

pub fn py2v_def_read_2_1() int {
	return keep_local(py2v_def_override_1_1(2))
}
