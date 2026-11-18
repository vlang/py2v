module main

import pyrt

fn show_py() ! {
	mut values := pyrt.box(pyrt.new_set([])!)
	alias := values
	println((pyrt.length(values)).str() + ' ' + (if !!(pyrt.length(values) > 0) {
		'True'
	} else {
		'False'
	}).str())
	pyrt.call_method(pyrt.box(values), 'add', [pyrt.box(true)])!
	pyrt.call_method(pyrt.box(values), 'add', [pyrt.box(1)])!
	pyrt.call_method(pyrt.box(values), 'add', [pyrt.box(2)])!
	println((pyrt.length(alias)).str() + ' ' + (if pyrt.has(alias, pyrt.box(1)) {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if pyrt.has(alias, pyrt.box(3)) { 'True' } else { 'False' }).str())
	pyrt.call_method(pyrt.box(alias), 'discard', [pyrt.box(1)])!
	println((pyrt.length(values)).str() + ' ' + (if pyrt.has(values, pyrt.box(2)) {
		'True'
	} else {
		'False'
	}).str())
	pyrt.call_method(pyrt.box(values), 'clear', [])!
	println(pyrt.length(alias))
	values = pyrt.box(pyrt.new_set([])!)
	pyrt.call_method(pyrt.box(values), 'add', [pyrt.box('new')])!
	println('${pyrt.length(values)} ${pyrt.length(alias)}')
	annotated := pyrt.box(pyrt.new_set([])!)
	pyrt.call_method(pyrt.box(annotated), 'add', [pyrt.box(4)])!
	println((if pyrt.has(annotated, pyrt.box(4)) { 'True' } else { 'False' }).str() + ' ' + (if pyrt.has(annotated, pyrt.box(5)) {
		'True'
	} else {
		'False'
	}).str())
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		pyrt.call_method(pyrt.box(values), 'add', [pyrt.empty_list()]) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'TypeError') != none {
			println('caught')
		} else {
			return py2v_raised_1
		}
	}
	println(pyrt.length(values))
}

fn show() {
	show_py() or { pyrt.fail(err) }
}

fn main() {
	show()
}
