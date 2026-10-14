module main

// TODO(py2v): no V equivalent for import py2many.smt
// Provide one in python_to_v_import (types.v) or port the module.

fn demorgan(a bool, b bool) bool {
	a && b == !(!a || !b)
}

fn main() {
	a := false
	b := false
	assert !demorgan(a, b)
	check_sat()
}
