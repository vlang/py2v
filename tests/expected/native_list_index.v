module main

import pyrt

fn index_py(values []string, target string) !int {
	return py2v_typed_list_index1(values, target)!
}

fn piece_index_py(target string) !int {
	pieces := [pyrt.none_, pyrt.box('p'), pyrt.box('n')]
	return py2v_dynamic_list_index1(pieces, target)!
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

fn py2v_entry1() ! {
	println(index_py(['r', 'q', 'r'], 'r')!)
	println(piece_index_py('n')!)
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

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
