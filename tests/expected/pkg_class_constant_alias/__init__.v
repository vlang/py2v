module py_pkg_class_constant_alias

pub const status_valid = py2v_class_status_valid_1
pub const status_busy = py2v_class_status_busy_1

const py2v_class_status_valid_1 = 0
const py2v_class_status_busy_1 = 8

pub struct Status {
}

pub fn total() int {
	return status_valid | status_busy
}
