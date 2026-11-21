module main

import pyrt

fn outer_py(value int) !int {
	return middle_py(value)! + 1
}

fn middle_py(value int) !int {
	return leaf_py(value)!
}

fn leaf_py(value int) !int {
	if value < 0 {
		return pyrt.raise('ValueError', 'invalid value')
	}
	return value
}

fn py2v_entry1() ! {
	outer_py(-1)!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
