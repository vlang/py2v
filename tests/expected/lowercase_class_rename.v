module main

pub struct Py2v_box {
pub mut:
	v int
}

fn (mut self Py2v_box) init(v_ int) {
	self.v = v_
}

// @staticmethod
fn Py2v_box.zero() Py2v_box {
	return py2v_new_py2v_box(0)
}

pub fn py2v_new_py2v_box(v_ int) Py2v_box {
	mut py2v_instance := Py2v_box{}
	py2v_instance.init(v_)
	return py2v_instance
}

pub struct Py2v_lower_1 {
pub mut:
	value int = 1
}

pub struct Py2v_lower {
pub mut:
	value int = 2
}

pub struct Item_1 {
pub mut:
	value int = 3
}

pub struct Item {
pub mut:
	value int = 4
}

pub struct A_struct_1 {
pub mut:
	value int = 5
}

pub struct A_struct {
pub mut:
	value int = 6
}

pub struct Py2v_base {
pub mut:
	x int
}

fn (mut self Py2v_base) init(x int) {
	self.x = x
}

fn (self Py2v_base) score() int {
	return self.x
}

pub fn py2v_new_py2v_base(x int) Py2v_base {
	mut py2v_instance := Py2v_base{}
	py2v_instance.init(x)
	return py2v_instance
}

pub struct Py2v_child {
	Py2v_base
pub mut:
	y int
}

fn (mut self Py2v_child) init(x int, y int) {
	self.Py2v_base.init(x)
	self.y = y
}

fn (self Py2v_child) total() int {
	return self.Py2v_base.score() + self.y
}

pub fn py2v_new_py2v_child(x int, y int) Py2v_child {
	mut py2v_instance := Py2v_child{}
	py2v_instance.init(x, y)
	return py2v_instance
}

fn unwrap(b Py2v_box) int {
	return b.v
}

fn sum_boxes(xs []Py2v_box, maybe ?Py2v_box) int {
	mut total := 0
	for item in xs {
		py2v_old1 := total
		py2v_aug_result2 := py2v_integer_add1(py2v_old1, item.v, 'lowercase_class_rename.py:61', 'addition')
		total = py2v_aug_result2
	}
	if maybe != none {
		py2v_old3 := total
		py2v_aug_result4 := py2v_old3 + maybe.v
		total = py2v_aug_result4
	}
	return total
}

fn apply_box(@fn fn (Py2v_box) int, b Py2v_box) int {
	return @fn(b)
}

fn union_box(maybe ?Py2v_box) int {
	if maybe != none {
		return maybe.v
	}
	return -1
}

fn check_box(b Py2v_box) int {
	if true {
		return 1
	}
	return 0
}

fn run() {
	b := py2v_new_py2v_box(7)
	mut empty := []Py2v_box{}
	empty << b
	println(unwrap(b))
	println(unwrap(Py2v_box.zero()))
	println(sum_boxes(empty, py2v_new_py2v_box(5)))
	println(apply_box(unwrap, py2v_new_py2v_box(11)))
	println('${union_box(py2v_new_py2v_box(13))} ${check_box(b)}')
	println((Py2v_lower_1{}.value).str() + ' ' + (Py2v_lower{}.value).str())
	println((Item_1{}.value).str() + ' ' + (Item{}.value).str())
	println((A_struct_1{}.value).str() + ' ' + (A_struct{}.value).str())
	println(py2v_new_py2v_child(10, 4).total())
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

fn main() {
	run()
}
