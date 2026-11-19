module main

import pyrt

// TODO(py2v): no V equivalent for import py2many.smt
// Provide one in python_to_v_import (types.v) or port the module.

fn equation_py(x int, y int) !bool {
	if pyrt.truth(pyrt.untranslated_import('py2many.smt.pre')!) {
		assert x > 2
		assert y < 10
		assert x + 2 * y == 7
	}
	true
}

fn equation(x int, y int) bool {
	return equation_py(x, y) or { pyrt.fail(err) }
}

fn fequation_py(z f64) !bool {
	if pyrt.truth(pyrt.untranslated_import('py2many.smt.pre')!) {
		assert 9.8 + 2 * z == z + 9.11
	}
	true
}

fn fequation(z f64) bool {
	return fequation_py(z) or { pyrt.fail(err) }
}

fn main() {
	x := (pyrt.untranslated_import('py2many.smt.default_value') or { pyrt.fail(err) })
	y := (pyrt.untranslated_import('py2many.smt.default_value') or { pyrt.fail(err) })
	z := (pyrt.untranslated_import('py2many.smt.default_value') or { pyrt.fail(err) })
	assert equation(x, y)
	assert fequation(z)
	(pyrt.untranslated_import('py2many.smt.check_sat') or { pyrt.fail(err) })
	(pyrt.untranslated_import('py2many.smt.get_value') or { pyrt.fail(err) })
}
