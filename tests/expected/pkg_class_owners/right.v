module py_pkg_class_owners

pub struct Py2vPoint2 {
pub mut:
	label string
}

pub fn (mut self Py2vPoint2) init(label string) {
	self.label = label
}

pub fn (self Py2vPoint2) text() string {
	return self.label
}

// @classmethod
pub fn py2v_point2_tagged(label string) string {
	return label + '!'
}

pub fn py2v_new_point_1(label string) Py2vPoint2 {
	mut py2v_instance := Py2vPoint2{}
	py2v_instance.init(label)
	return py2v_instance
}
