module main

import pyrt

type Any = pyrt.Value

fn caught_type_py(value Any) ! {
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		pyrt.call_method(pyrt.box(value), 'join', [pyrt.box([1])]) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if error := pyrt.caught(py2v_raised_1, 'TypeError') {
			println('caught type ${error.str()}')
		} else {
			return py2v_raised_1
		}
	}
}

fn caught_attr_py(value Any) ! {
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		pyrt.call_method(pyrt.box(value), 'append', [pyrt.box(2)]) or {
			py2v_err_2 = err
			break py2v_try_2
		}
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if error := pyrt.caught(py2v_raised_2, 'AttributeError') {
			println('caught attribute ${error.str()}')
		} else {
			return py2v_raised_2
		}
	}
}

fn relay_py(value Any) ! {
	pyrt.call_method(pyrt.box(value), 'append', [pyrt.box(2)])!
}

fn propagate_py(value Any) ! {
	relay_py(value)!
}

fn receiver() Any {
	println('receiver')
	return pyrt.empty_list()
}

fn argument() int {
	println('argument')
	return 7
}

fn success_py(value Any) ! {
	pyrt.call_method(pyrt.box(value), 'append', [pyrt.box(3)])!
	println(pyrt.str(value))
}

fn side(label string) string {
	println(label)
	return label
}

fn py2v_entry1() ! {
	caught_type_py('')!
	caught_attr_py(1)!
	mut py2v_err_3 := ?IError(none)
	py2v_try_3: for {
		propagate_py(1) or {
			py2v_err_3 = err
			break py2v_try_3
		}
		break
	}
	if py2v_raised_3 := py2v_err_3 {
		if pyrt.caught(py2v_raised_3, 'AttributeError') != none {
			println('propagated')
		} else {
			pyrt.fail(py2v_raised_3)
		}
	}
	value := receiver()
	pyrt.call_method(pyrt.box(value), 'append', [pyrt.box(argument())])!
	success_py(pyrt.empty_list())!
	println((side('first')).str() + ' ' + (pyrt.str(pyrt.call_method(pyrt.box(receiver()), 'append', [pyrt.box(1)])!)).str())
	effects := [pyrt.box(side('third')),
		pyrt.call_method(pyrt.box(receiver()), 'append', [pyrt.box(2)])!]
	println(effects.len)
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
