module py_pkg_class_owners

pub struct Py2vPoint1 {
pub mut:
	x int
}

pub fn (mut self Py2vPoint1) init(x int) {
	self.x = x
}

pub fn (self Py2vPoint1) value() int {
	return self.x
}

// @staticmethod
pub fn py2v_point1_origin_x() int {
	return 3
}

pub fn py2v_new_point(x int) Py2vPoint1 {
	mut py2v_instance := Py2vPoint1{}
	py2v_instance.init(x)
	return py2v_instance
}
