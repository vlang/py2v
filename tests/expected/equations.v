module main

import pyrt

// TODO(py2v): no V equivalent for import py2many.smt
// Provide one in python_to_v_import (types.v) or port the module.

fn equation_py(x int, y int) !bool {
	if pyrt.truth(pyrt.untranslated_import('py2many.smt.pre')!) {
		assert x > 2
		assert y < 10
		assert x + int(py2v_integer_mul1(2, y, 'equations.py:13', 'multiplication')) == 7
	}
	true
}

fn fequation_py(z f64) !bool {
	if pyrt.truth(pyrt.untranslated_import('py2many.smt.pre')!) {
		assert 9.8 + 2 * z == z + 9.11
	}
	true
}

fn py2v_entry1() ! {
	x := pyrt.untranslated_import('py2many.smt.default_value')!
	y := pyrt.untranslated_import('py2many.smt.default_value')!
	z := pyrt.untranslated_import('py2many.smt.default_value')!
	assert equation_py(x, y)!
	assert fequation_py(z)!
	pyrt.untranslated_import('py2many.smt.check_sat')!
	pyrt.untranslated_import('py2many.smt.get_value')!
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

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
