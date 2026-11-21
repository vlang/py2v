module main

import pyrt

type Any = pyrt.Value

fn by_index(index int) map[string]Any {
	return {
		'name':    pyrt.box('rook')
		'squares': pyrt.box([pyrt.box(index), pyrt.box(8)])
	}
}

fn show_py(name string) ! {
	mut config := map[string]Any{}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		config = by_index(py2v_typed_list_index1(['yes'], name) or {
			py2v_err_1 = err
			break py2v_try_1
		})
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'ValueError') != none {
			println('missing')
			return
		} else {
			return py2v_raised_1
		}
	}
	println(pyrt.str(config['name']))
	println(pyrt.str(config['squares']))
}

fn show(name string) {
	show_py(name) or { pyrt.fail(err) }
}

fn py2v_typed_list_index1[T](items []T, needle T) !int {
	index := items.index(needle)
	if index < 0 {
		return pyrt.raise('ValueError', pyrt.repr(pyrt.box(needle)) + ' is not in list')
	}
	return index
}

fn main() {
	show('yes')
	show('no')
}
