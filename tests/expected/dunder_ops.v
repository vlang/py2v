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
		py2v_init_arg1 := py2v_integer_add1(self.x, other.x, 'dunder_ops.py:7', 'addition')
		py2v_init_arg2 := py2v_integer_add1(self.y, other.y, 'dunder_ops.py:7', 'addition')
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
		py2v_init_arg3 := py2v_integer_neg1(self.x, 'dunder_ops.py:22')
		py2v_init_arg4 := py2v_integer_neg1(self.y, 'dunder_ops.py:22')
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

fn describe(p _Private) string {
	return repr(p) + p.str()
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

@[inline]
fn py2v_integer_neg1(value int, site string) int {
	if value == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'negation') }
	return -value
}

fn main() {
	v1 := py2v_new_vector(1, 2)
	v2 := py2v_new_vector(3, 4)
	v3 := v1 + v2
	println(v3)
}
