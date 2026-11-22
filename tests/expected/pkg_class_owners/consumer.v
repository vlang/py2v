module py_pkg_class_owners

import math

pub struct Shifted {
	Py2vPoint1
}

pub fn (mut self Shifted) init(x int) {
	self.Py2vPoint1.init(x)
}

pub fn (self Shifted) shifted() int {
	return py2v_integer_generic_add1(self.value(), 1, 'consumer.py:11', |py2v_operand1, py2v_operand2| py2v_operand1 + py2v_operand2)
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

fn py2v_integer_generic_add1[A, B, R](a A, b B, site string, fallback fn (A, B) R) R {
	$if A is $int && B is $int && R is $int {
		$if A is u64 || B is u64 || R is u64 {
			$compile_error('py2v_unsupported_wide_integer: generic arithmetic needs a signed native result')
		} $else {
			value := py2v_integer_add1(int(a), int(b), site, 'addition')
			if value < int(math.minof[R]()) || value > int(math.maxof[R]()) {
				py2v_integer_overflow1(site, 'integer narrowing')
			}
			return R(value)
		}
	} $else {
		return fallback(a, b)
	}
}
