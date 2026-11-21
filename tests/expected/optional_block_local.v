module main

import pyrt

fn promotion(use_piece bool, symbol string) ?int {
	mut selected := ?int(none)
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		selected = if use_piece {
			py2v_typed_list_index1(['n', 'b'], symbol) or {
				py2v_err_1 = err
				break py2v_try_1
			}
		} else {
			none
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'ValueError') != none {
			return none
		} else {
			pyrt.fail(py2v_raised_1)
		}
	}
	return selected
}

fn py2v_typed_list_index1[T](items []T, needle T) !int {
	index := items.index(needle)
	if index < 0 {
		return pyrt.raise('ValueError', pyrt.repr(pyrt.box(needle)) + ' is not in list')
	}
	return index
}

fn main() {
	chosen := promotion(true, 'b')
	if chosen != none {
		println(chosen)
	}
	println(if promotion(false, 'b') == none { 'True' } else { 'False' })
	println(if promotion(true, 'x') == none { 'True' } else { 'False' })
}
