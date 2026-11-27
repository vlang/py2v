module main

pub struct Vector {
pub mut:
	x int
	y int
}

fn (mut self Vector) init(x int, y int) {
	self.x = x
	self.y = y
}

fn (self Vector) + (other Vector) Vector {
	return (fn [other, self] () Vector {
		py2v_init_arg1 := self.x + other.x
		py2v_init_arg2 := self.y + other.y
		return py2v_new_vector(py2v_init_arg1, py2v_init_arg2)
	})()
}

fn (self Vector) == (other Vector) bool {
	return self.x == other.x && self.y == other.y
}

fn (self Vector) str() string {
	return 'Vector(${self.x}, ${self.y})'
}

fn (self Vector) py2v_dunder_repr() string {
	return 'Vector(${self.x}, ${self.y})'
}

fn (self Vector) len() int {
	return 2
}

fn (self Vector) py_neg() Vector {
	return (fn [self] () Vector {
		py2v_init_arg3 := -self.x
		py2v_init_arg4 := -self.y
		return py2v_new_vector(py2v_init_arg3, py2v_init_arg4)
	})()
}

pub fn py2v_new_vector(x int, y int) Vector {
	mut py2v_instance := Vector{}
	py2v_instance.init(x, y)
	return py2v_instance
}

pub struct Private {
pub mut:
	tag string
}

fn (mut self Private) init(tag string) {
	self.tag = tag
}

fn (self Private) label() string {
	return self.tag
}

pub fn py2v_new_private(tag string) Private {
	mut py2v_instance := Private{}
	py2v_instance.init(tag)
	return py2v_instance
}

fn describe(p Private) string {
	return repr(p) + p.str()
}

fn main() {
	v1 := py2v_new_vector(1, 2)
	v2 := py2v_new_vector(3, 4)
	v3 := v1 + v2
	println(v3)
}
