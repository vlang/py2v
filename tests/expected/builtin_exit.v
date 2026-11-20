module main

import os
import pyrt

fn exit_argument() int {
	println('argument evaluated')
	return 4
}

fn direct_finally() {
	defer {
		println('direct cleanup')
	}
	py2v_py2v_exit1 := pyrt.raise('SystemExit', 'direct message')
	println('direct cleanup')
	pyrt.fail(py2v_py2v_exit1)
}

fn sys_finally() {
	defer {
		println('sys cleanup')
	}
	py2v_py2v_exit2 := IError(pyrt.exception('SystemExit', [pyrt.box(exit_argument())]))
	println('sys cleanup')
	pyrt.fail(py2v_py2v_exit2)
}

fn nested_finally() {
	defer {
		println('outer cleanup')
	}
	defer {
		py2v_py2v_exit3 := IError(pyrt.exception('SystemExit', [pyrt.box(3)]))
		println('outer cleanup')
		pyrt.fail(py2v_py2v_exit3)
	}
	py2v_py2v_exit4 := IError(pyrt.exception('SystemExit', [pyrt.box(2)]))
	py2v_py2v_exit5 := IError(pyrt.exception('SystemExit', [pyrt.box(3)]))
	println('outer cleanup')
	pyrt.fail(py2v_py2v_exit5)
	println('outer cleanup')
	pyrt.fail(py2v_py2v_exit4)
}

fn nested_cleanups() {
	defer {
		println('outer cleanup')
	}
	defer {
		println('inner cleanup')
	}
	py2v_py2v_exit6 := IError(pyrt.exception('SystemExit', [pyrt.box(2)]))
	println('inner cleanup')
	println('outer cleanup')
	pyrt.fail(py2v_py2v_exit6)
}

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
		exit(0)
	} else if mode == 'int' {
		exit(7)
	} else if mode == 'true' {
		exit(1)
	} else if mode == 'false' {
		exit(0)
	} else if mode == 'none' {
		pyrt.fail(IError(pyrt.exception('SystemExit', [pyrt.none_])))
	} else if mode == 'message' {
		eprintln('message')
		exit(1)
	} else if mode == 'direct_finally' {
		direct_finally()
	} else if mode == 'sys_finally' {
		sys_finally()
	} else if mode == 'nested_finally' {
		nested_finally()
	} else if mode == 'nested_cleanups' {
		nested_cleanups()
	}
}
