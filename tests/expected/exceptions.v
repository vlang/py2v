module main

import pyrt

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except Exception as e (1 stmt)

fn show() {
	defer {
		println('Finally')
	}
	panic('Exception: ' + 'foo')
	// except handlers are not translated: see the TODO(py2v) note above
	//   except Exception as e: 1 statement(s) need an `or { ... }` equivalent
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		py2v_err_2 = pyrt.raise('Exception', 'foo')
		break py2v_try_2
	}
	if py2v_err_2 != none {
		{
			println('Got it')
		}
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		py2v_err_1 = pyrt.raise('Exception', 'foo')
		break py2v_try_1
	}
	if py2v_raised_1 := py2v_err_1 {
		if e := pyrt.caught(py2v_raised_1, 'Exception') {
			assert e.str().contains('foo')
		} else {
			pyrt.fail(py2v_raised_1)
		}
	}
}

fn main() {
	show()
}
