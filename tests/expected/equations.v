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

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
