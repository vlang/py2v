module main

import pyrt

const global = (pyrt.frozenset_from(pyrt.box(pyrt.Value((pyrt.new_set([
	pyrt.box('alpha'),
	pyrt.box('beta'),
]) or { pyrt.fail(err) })))) or { pyrt.fail(err) })

const signed = (pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(-pyrt.to_float(pyrt.box(0.0)))]))) or { pyrt.fail(err) })

fn item() int {
	println('left')
	return 1
}

fn members() []int {
	println('right')
	return [1]
}

fn show_py() ! {
	mut bad := pyrt.none_
	empty := pyrt.frozenset_from(pyrt.box(pyrt.empty_list()))!
	numbers := pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(1), pyrt.box(2), pyrt.box(1)])))!
	words := pyrt.frozenset_from(pyrt.box(pyrt.box('αaα')))!
	nested := pyrt.frozenset_from(pyrt.box(pyrt.box([
		pyrt.Value(pyrt.new_tuple([pyrt.box(1), pyrt.box(2)])),
		pyrt.Value(pyrt.new_tuple([pyrt.box(1), pyrt.box(2)])),
		pyrt.Value(pyrt.new_tuple([pyrt.box(3), pyrt.box(4)])),
	])))!
	equivalent := pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(true), pyrt.box(1),
		pyrt.box(pyrt.to_float(pyrt.box(1.0)))])))!
	println('${pyrt.length(empty)} ${pyrt.length(numbers)} ${pyrt.length(words)} ${pyrt.length(nested)} ${pyrt.length(equivalent)}')
	println('${pyrt.str(pyrt.item_in(pyrt.box(pyrt.box(1)), pyrt.box(numbers))!)} ${pyrt.str(pyrt.item_in(pyrt.box(pyrt.box(3)), pyrt.box(numbers))!)}')
	println('${pyrt.length(global)} ${pyrt.length(pyrt.frozenset_from(pyrt.box(pyrt.Value(pyrt.new_tuple(pyrt.elements(pyrt.empty_list())))))!)} ${pyrt.length(pyrt.frozenset_from(pyrt.box(pyrt.empty_dict()))!)}')
	println(pyrt.str(pyrt.item_in(pyrt.box(pyrt.box(item())), pyrt.box(pyrt.frozenset_from(pyrt.box(pyrt.box(members())))!))!))
	println(pyrt.str(pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(pyrt.to_float(pyrt.box(1.0)))])))!))
	println(pyrt.str(pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(-pyrt.to_float(pyrt.box(0.0)))])))!))
	number := 1.0
	assert number == 1.0
	println(pyrt.str(pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box(pyrt.to_float(pyrt.box(1.0)))])))!))
	println(pyrt.str(signed))
	println((if !pyrt.truth(pyrt.item_in(pyrt.box(pyrt.box(1)), pyrt.box(numbers))!) {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if !pyrt.truth(pyrt.item_in(pyrt.box(pyrt.box(3)), pyrt.box(numbers))!) {
		'True'
	} else {
		'False'
	}).str())
	mut py2v_err_3 := ?IError(none)
	py2v_try_3: for {
		bad = pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.empty_list()]))) or {
			py2v_err_3 = err
			break py2v_try_3
		}
		println(pyrt.length(bad))
		break
	}
	if py2v_raised_3 := py2v_err_3 {
		if pyrt.caught(py2v_raised_3, 'TypeError') != none {
			println('unhashable')
		} else {
			return py2v_raised_3
		}
	}
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		println(pyrt.str(pyrt.item_in(pyrt.box(pyrt.empty_list()), pyrt.box(numbers)) or {
			py2v_err_2 = err
			break py2v_try_2
		}))
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if pyrt.caught(py2v_raised_2, 'TypeError') != none {
			println('member error')
		} else {
			return py2v_raised_2
		}
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		bad = pyrt.frozenset_from(pyrt.box(pyrt.none_)) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		println(pyrt.length(bad))
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'TypeError') != none {
			println('not iterable')
		} else {
			return py2v_raised_1
		}
	}
}

fn py2v_entry1() ! {
	show_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
