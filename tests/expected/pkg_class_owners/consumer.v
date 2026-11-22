module py_pkg_class_owners

pub struct Shifted {
	Py2vPoint1
}

pub fn (mut self Shifted) init(x int) {
	self.Py2vPoint1.init(x)
}

pub fn (self Shifted) shifted() int {
	return self.value() + 1
}

pub fn py2v_new_shifted(x int) Shifted {
	mut py2v_instance := Shifted{}
	py2v_instance.init(x)
	return py2v_instance
}

pub struct Box {
pub mut:
	points []Py2vPoint1
}

pub fn keep(point Py2vPoint1) Py2vPoint1 {
	return point
}

pub fn total() string {
	origin := py2v_new_point(py2v_point1_origin_x())
	shifted := py2v_new_shifted(5)
	label := py2v_new_point_1(py2v_point2_tagged('point'))
	if !true {
		return 'wrong Coordinate'
	}
	if false {
		return 'wrong Label'
	}
	return label.text() + ' ' + (keep(origin).value()).str() + ' ' + (shifted.shifted()).str()
}
