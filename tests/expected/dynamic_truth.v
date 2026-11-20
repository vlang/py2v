module main

import pyrt

type Any = pyrt.Value

fn report(value Any) {
	println(if !!pyrt.truth(value) { 'True' } else { 'False' })
	println(if !pyrt.truth(value) { 'True' } else { 'False' })
}

fn invert(value bool) bool {
	return !value
}

fn combined(left Any, right int) {
	if pyrt.truth(pyrt.plus(left, pyrt.box(right))) {
		println('nonzero')
	} else {
		println('zero')
	}
}

fn main() {
	report(0)
	report(1)
	report('')
	report('a')
	report(pyrt.empty_list())
	report(pyrt.box([pyrt.box(1)]))
	report(pyrt.empty_dict())
	report(pyrt.box(map[string]Any{
		'x': pyrt.box(1)
	}))
	report(pyrt.none_)
	println(if invert(true) { 'True' } else { 'False' })
	combined(0, 0)
	combined(1, 0)
}
