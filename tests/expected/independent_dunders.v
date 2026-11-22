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
	return py2v_new_number(py2v_integer_add1(self.value, other.value, 'independent_dunders.py:26', 'addition'))
}

fn (self Number) py_floor_div(other Number) int {
	return py2v_integer_floor_div1(self.value, other.value, 'independent_dunders.py:29')
}

fn (self Number) + (other Number) Number {
	return py2v_new_number(py2v_integer_add1(self.value, other.value, 'independent_dunders.py:32', 'addition'))
}

fn (self Number) py_pos() int {
	return py2v_integer_add1(self.value, 10, 'independent_dunders.py:35', 'addition')
}

fn (self Number) - (other Number) Number {
	return py2v_new_number(py2v_integer_sub1(self.value, other.value, 'independent_dunders.py:38', 'subtraction'))
}

fn (self Number) py_neg() int {
	return py2v_integer_sub1(10, self.value, 'independent_dunders.py:41', 'subtraction')
}

fn (self Number) py_invert() int {
	return py2v_integer_add1(self.value, 20, 'independent_dunders.py:44', 'addition')
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
fn py2v_integer_floor_div1(a int, b int, site string) int {
	if b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }
	if b == -1 && a == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'floor division') }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return a / b - int(adjust)
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
}

fn main() {
	check(py2v_new_number(5), py2v_new_number(2))
}
