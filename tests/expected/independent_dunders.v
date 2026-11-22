module main

pub struct Number {
pub mut:
	value int
}

fn (mut self Number) init(value int) {
	self.value = value
}

fn (self Number) == (other Number) bool {
	return self.value == other.value
}

fn (self Number) < (other Number) bool {
	return self.value < other.value
}

fn (self Number) py_ne(other Number) bool {
	return self.value == other.value
}

fn (self Number) py_le(other Number) bool {
	return self.value < other.value
}

fn (self Number) py_gt(other Number) bool {
	return self.value < other.value
}

fn (self Number) py_ge(other Number) bool {
	return self.value < other.value
}

fn (self Number) / (other Number) Number {
	return py2v_new_number(self.value + other.value)
}

fn (self Number) py_floor_div(other Number) int {
	return py2v_integer_floor_div1(self.value, other.value, 'independent_dunders.py:29')
}

fn (self Number) + (other Number) Number {
	return py2v_new_number(self.value + other.value)
}

fn (self Number) py_pos() int {
	return self.value + 10
}

fn (self Number) - (other Number) Number {
	return py2v_new_number(self.value - other.value)
}

fn (self Number) py_neg() int {
	return 10 - self.value
}

fn (self Number) py_invert() int {
	return self.value + 20
}

pub fn py2v_new_number(value int) Number {
	mut py2v_instance := Number{}
	py2v_instance.init(value)
	return py2v_instance
}

fn check(a Number, b Number) {
	println(if a.py_ne(b) { 'True' } else { 'False' })
	println(if a.py_le(b) { 'True' } else { 'False' })
	println(if a.py_gt(b) { 'True' } else { 'False' })
	println(if a.py_ge(b) { 'True' } else { 'False' })
	println(a.py_floor_div(b))
	println(a.py_neg())
	println(a.py_pos())
	println(a.py_invert())
	println(if a.py_ne(b) { 'True' } else { 'False' })
}

@[inline]
fn py2v_integer_floor_div1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return a / b - int(adjust)
}

fn main() {
	check(py2v_new_number(5), py2v_new_number(2))
}
