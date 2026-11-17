module main

import os
import pyrt

fn caught_py() ! {
	mut py2v_err_4 := ?IError(none)
	py2v_try_4: for {
		py2v_err_4 = IError(pyrt.exception('SystemExit', [pyrt.box(3)]))
		break py2v_try_4
	}
	if py2v_raised_4 := py2v_err_4 {
		if error := pyrt.caught(py2v_raised_4, 'SystemExit') {
			println('caught ${error}')
		} else {
			return py2v_raised_4
		}
	}
	mut py2v_err_3 := ?IError(none)
	py2v_try_3: for {
		py2v_err_3 = pyrt.raise('SystemExit', 'message')
		break py2v_try_3
	}
	if py2v_raised_3 := py2v_err_3 {
		if pyrt.caught(py2v_raised_3, 'Exception') != none {
			println('wrong')
		} else if error := pyrt.caught(py2v_raised_3, 'BaseException') {
			println('base ${error}')
		} else {
			return py2v_raised_3
		}
	}
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		py2v_err_2 = IError(pyrt.exception('SystemExit', []pyrt.Value{}))
		break py2v_try_2
	}
	if py2v_raised_2 := py2v_err_2 {
		if pyrt.caught(py2v_raised_2, 'SystemExit') != none {
			println('default')
		} else {
			return py2v_raised_2
		}
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		py2v_err_1 = IError(pyrt.exception('SystemExit', [pyrt.none_]))
		break py2v_try_1
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'SystemExit') != none {
			println('none')
		} else {
			return py2v_raised_1
		}
	}
}

fn caught() {
	caught_py() or { pyrt.fail(err) }
}

fn main() {
	mode := os.args[1]
	if mode == 'caught' {
		caught()
	} else if mode == 'zero' {
		pyrt.fail(IError(pyrt.exception('SystemExit', []pyrt.Value{})))
	} else if mode == 'int' {
		pyrt.fail(IError(pyrt.exception('SystemExit', [pyrt.box(7)])))
	} else if mode == 'true' {
		pyrt.fail(IError(pyrt.exception('SystemExit', [pyrt.box(true)])))
	} else if mode == 'false' {
		pyrt.fail(IError(pyrt.exception('SystemExit', [pyrt.box(false)])))
	} else if mode == 'none' {
		pyrt.fail(IError(pyrt.exception('SystemExit', [pyrt.none_])))
	} else if mode == 'message' {
		pyrt.fail(pyrt.raise('SystemExit', 'message'))
	}
}
