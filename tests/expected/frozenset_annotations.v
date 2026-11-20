module main

import pyrt

type Any = pyrt.Value

fn count(values Any) int {
	return pyrt.length(values)
}

fn contains(values Any, name string) bool {
	return pyrt.has(values, pyrt.box(name))
}

fn nonempty(values Any) bool {
	return !!pyrt.truth(values)
}

fn build_py() !Any {
	return pyrt.frozenset_from(pyrt.box(pyrt.box([pyrt.box('red'), pyrt.box('blue'), pyrt.box('red')])))!
}

fn build() Any {
	return build_py() or { pyrt.fail(err) }
}

fn show_py() ! {
	values := build_py()!
	println((count(values)).str() + ' ' + (if contains(values, 'red') { 'True' } else { 'False' }).str() + ' ' + (if contains(values, 'green') {
		'True'
	} else {
		'False'
	}).str())
	alias := pyrt.call_method(pyrt.box(values), 'copy', [])!
	println((pyrt.length(alias)).str() + ' ' + (if pyrt.eq(alias, values) {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if nonempty(alias) { 'True' } else { 'False' }).str())
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		pyrt.call_method(pyrt.box(values), 'add', [pyrt.box('new')]) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'AttributeError') != none {
			println('immutable')
		} else {
			return py2v_raised_1
		}
	}
}

fn show() {
	show_py() or { pyrt.fail(err) }
}

fn main() {
	show()
}
