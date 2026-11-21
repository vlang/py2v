module main

import pyrt

fn index_py(values []string, target string) !int {
	return py2v_typed_list_index1(values, target)!
}

fn index(values []string, target string) int {
	return index_py(values, target) or { pyrt.fail(err) }
}

fn piece_index_py(target string) !int {
	pieces := [pyrt.none_, pyrt.box('p'), pyrt.box('n')]
	return py2v_dynamic_list_index1(pieces, target)!
}

fn piece_index(target string) int {
	return piece_index_py(target) or { pyrt.fail(err) }
}

fn py2v_typed_list_index1[T](items []T, needle T) !int {
	index := items.index(needle)
	if index < 0 {
		return pyrt.raise('ValueError', pyrt.repr(pyrt.box(needle)) + ' is not in list')
	}
	return index
}

fn py2v_dynamic_list_index1[T, U](items T, needle U) !int {
	return pyrt.to_int(pyrt.call_method(pyrt.box(items), 'index', [pyrt.box(needle)])!)
}

fn main() {
	println(index(['r', 'q', 'r'], 'r'))
	println(piece_index('n'))
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		println(index_py(['r', 'q'], 'x') or {
			py2v_err_1 = err
			break py2v_try_1
		})
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'ValueError') != none {
			println('missing')
		} else {
			pyrt.fail(py2v_raised_1)
		}
	}
}
