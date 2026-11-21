module main

import pyrt

fn from_try_py(flag bool) !int {
	mut result := 0
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		if !flag {
			py2v_err_1 = pyrt.raise('ValueError', 'x')
			break py2v_try_1
		}
		result = 10
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'ValueError') != none {
			result = 20
		} else {
			return py2v_raised_1
		}
	}
	return result
}

fn py2v_entry1() ! {
	println(from_try_py(true)!)
	println(from_try_py(false)!)
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
