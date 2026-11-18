module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

fn pair_py(value Any) ! {
	py2v_unpack1 := pyrt.unpack(pyrt.box(value), 2)!
	mut first := py2v_unpack1[0]
	mut second := py2v_unpack1[1]
	println(pyrt.str(pyrt.call_method(pyrt.box(first), 'upper', [])!))
	println(pyrt.str(pyrt.item_at(second, pyrt.box('n'))))
}

fn pair(value Any) {
	pair_py(value) or { pyrt.fail(err) }
}

fn list_pair_py(value Any) ! {
	py2v_unpack2 := pyrt.unpack(pyrt.box(value), 2)!
	first := py2v_unpack2[0]
	second := py2v_unpack2[1]
	println(pyrt.str(pyrt.call_method(pyrt.box(first), 'upper', [])!))
	println(pyrt.str(second))
}

fn list_pair(value Any) {
	list_pair_py(value) or { pyrt.fail(err) }
}

fn discarded_py(value Any) ! {
	py2v_unpack3 := pyrt.unpack(pyrt.box(value), 2)!
	_ = py2v_unpack3[0]
	mut second := py2v_unpack3[1]
	println(pyrt.str(second))
}

fn discarded(value Any) {
	discarded_py(value) or { pyrt.fail(err) }
}

fn pairs_py(values Any) ! {
	has_break := false
	for py2v_dynamic_iter_0 in pyrt.elements(values) {
		py2v_unpack4 := pyrt.unpack(pyrt.box(py2v_dynamic_iter_0), 2)!
		mut first := py2v_unpack4[0]
		mut second := py2v_unpack4[1]
		println(pyrt.str(pyrt.call_method(pyrt.box(first), 'upper', [])!))
		println(pyrt.str(pyrt.item_at(second, pyrt.box('n'))))
	}
	if has_break != true {
		println('done')
	}
}

fn pairs(values Any) {
	pairs_py(values) or { pyrt.fail(err) }
}

fn arity_py(value Any) ! {
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		py2v_unpack5 := pyrt.unpack(pyrt.box(value), 2) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		mut left := py2v_unpack5[0]
		mut right := py2v_unpack5[1]
		println(pyrt.str(left))
		println(pyrt.str(right))
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'ValueError') != none {
			println('arity')
		} else {
			return py2v_raised_1
		}
	}
}

fn arity(value Any) {
	arity_py(value) or { pyrt.fail(err) }
}

fn main() {
	pair(pyrt.box([pyrt.box('ada'), pyrt.box(map[string]Any{
		'n': pyrt.box(3)
	})]))
	list_pair(pyrt.box([pyrt.box('bea'), pyrt.box(4)]))
	discarded(pyrt.box([pyrt.box(9), pyrt.box(8)]))
	pairs(pyrt.box([
		pyrt.box([pyrt.box('cat'), pyrt.box(map[string]Any{
			'n': pyrt.box(5)
		})]),
		pyrt.box([pyrt.box('dog'), pyrt.box(map[string]Any{
			'n': pyrt.box(6)
		})]),
	]))
	arity(pyrt.box([pyrt.box(1)]))
	arity(pyrt.box([pyrt.box(1), pyrt.box(2), pyrt.box(3)]))
	arity(pyrt.box([pyrt.box(1), pyrt.box(2)]))
}
