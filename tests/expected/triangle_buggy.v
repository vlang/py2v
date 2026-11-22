module main

import pyrt

// TODO(py2v): no V equivalent for import adt, py2many.smt
// Provide one in python_to_v_import (types.v) or port the module.

pub struct TriangleType {
pub mut:
	EQUILATERAL int
	ISOSCELES   int
	RIGHT       int
	ACUTE       int
	OBTUSE      int
	ILLEGAL     int
}

fn classify_triangle_correct(a int, b int, c int) TriangleType {
	if a == b && b == c {
		return TriangleType.EQUILATERAL
	} else if a == b || b == c || a == c {
		return TriangleType.ISOSCELES
	} else if a >= b && a >= c {
		if py2v_integer_mul1(a, a, 'triangle_buggy.py:39', 'multiplication') == py2v_integer_add1(int(py2v_integer_mul1(b, b, 'triangle_buggy.py:39', 'multiplication')), int(py2v_integer_mul1(c, c, 'triangle_buggy.py:39', 'multiplication')), 'triangle_buggy.py:39', 'addition') {
			return TriangleType.RIGHT
		} else if py2v_integer_mul1(a, a, 'triangle_buggy.py:41', 'multiplication') < py2v_integer_add1(int(py2v_integer_mul1(b, b, 'triangle_buggy.py:41', 'multiplication')), int(py2v_integer_mul1(c, c, 'triangle_buggy.py:41', 'multiplication')), 'triangle_buggy.py:41', 'addition') {
			return TriangleType.ACUTE
		} else {
			return TriangleType.OBTUSE
		}
	} else if b >= a && b >= c {
		if py2v_integer_mul1(b, b, 'triangle_buggy.py:47', 'multiplication') == py2v_integer_add1(int(py2v_integer_mul1(a, a, 'triangle_buggy.py:47', 'multiplication')), int(py2v_integer_mul1(c, c, 'triangle_buggy.py:47', 'multiplication')), 'triangle_buggy.py:47', 'addition') {
			return TriangleType.RIGHT
		} else if py2v_integer_mul1(b, b, 'triangle_buggy.py:49', 'multiplication') < py2v_integer_add1(int(py2v_integer_mul1(a, a, 'triangle_buggy.py:49', 'multiplication')), int(py2v_integer_mul1(c, c, 'triangle_buggy.py:49', 'multiplication')), 'triangle_buggy.py:49', 'addition') {
			return TriangleType.ACUTE
		} else {
			return TriangleType.OBTUSE
		}
	} else if py2v_integer_mul1(c, c, 'triangle_buggy.py:55', 'multiplication') == py2v_integer_add1(int(py2v_integer_mul1(a, a, 'triangle_buggy.py:55', 'multiplication')), int(py2v_integer_mul1(b, b, 'triangle_buggy.py:55', 'multiplication')), 'triangle_buggy.py:55', 'addition') {
		return TriangleType.RIGHT
	} else if py2v_integer_mul1(c, c, 'triangle_buggy.py:57', 'multiplication') < py2v_integer_add1(int(py2v_integer_mul1(a, a, 'triangle_buggy.py:57', 'multiplication')), int(py2v_integer_mul1(b, b, 'triangle_buggy.py:57', 'multiplication')), 'triangle_buggy.py:57', 'addition') {
		return TriangleType.ACUTE
	} else {
		return TriangleType.OBTUSE
	}
}

fn classify_triangle_py(a int, b int, c int) !TriangleType {
	if pyrt.truth(pyrt.untranslated_import('py2many.smt.pre')!) {
		assert a > 0
		assert b > 0
		assert c > 0
		assert a < py2v_integer_add1(b, c, 'triangle_buggy.py:70', 'addition')
	}
	if a >= b && b >= c {
		if a == c || b == c {
			if a == b && a == c {
				return TriangleType.EQUILATERAL
			} else {
				return TriangleType.ISOSCELES
			}
		} else if py2v_integer_mul1(a, a, 'triangle_buggy.py:82', 'multiplication') != py2v_integer_add1(int(py2v_integer_mul1(b, b, 'triangle_buggy.py:82', 'multiplication')), int(py2v_integer_mul1(c, c, 'triangle_buggy.py:82', 'multiplication')), 'triangle_buggy.py:82', 'addition') {
			if py2v_integer_mul1(a, a, 'triangle_buggy.py:83', 'multiplication') < py2v_integer_add1(int(py2v_integer_mul1(b, b, 'triangle_buggy.py:83', 'multiplication')), int(py2v_integer_mul1(c, c, 'triangle_buggy.py:83', 'multiplication')), 'triangle_buggy.py:83', 'addition') {
				return TriangleType.ACUTE
			} else {
				return TriangleType.OBTUSE
			}
		} else {
			return TriangleType.RIGHT
		}
	} else {
		return TriangleType.ILLEGAL
	}
}

fn py2v_entry1() ! {
	a := pyrt.untranslated_import('py2many.smt.default_value')!
	b := pyrt.untranslated_import('py2many.smt.default_value')!
	c := pyrt.untranslated_import('py2many.smt.default_value')!
	assert !(classify_triangle_correct(a, b, c) == classify_triangle_py(a, b, c)!)
	pyrt.untranslated_import('py2many.smt.check_sat')!
	pyrt.untranslated_import('py2many.smt.get_model')!
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
