module main

import pyrt

fn leaf_py(value int) !int {
	if value < 0 {
		return pyrt.raise('ValueError', 'invalid value')
	}
	return value
}

fn middle_py(value int) !int {
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		return leaf_py(value) or {
			py2v_err_1 = err
			break py2v_try_1
		}
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'ValueError') != none {
			return py2v_raised_1
		} else {
			return py2v_raised_1
		}
	} else {
		pyrt.unreachable()
	}
}

fn outer_py(value int) !int {
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		return middle_py(value) or {
			py2v_err_2 = err
			break py2v_try_2
		}
	}
	if py2v_raised_2 := py2v_err_2 {
		if problem := pyrt.caught(py2v_raised_2, 'ValueError') {
			println(problem.str())
			return 0
		} else {
			return py2v_raised_2
		}
	} else {
		pyrt.unreachable()
	}
}

fn py2v_entry1() ! {
	println(outer_py(-1)!)
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
