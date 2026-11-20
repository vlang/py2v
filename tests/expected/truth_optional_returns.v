module main

import pyrt

type Any = pyrt.Value

fn maybe(value Any) ?Any {
	println('maybe')
	if pyrt.is_none(value) {
		return none
	}
	return value
}

fn maybe_object(value Any) ?Any {
	println('object')
	return value
}

fn report(value Any) {
	item := maybe(value)
	alias := item
	if pyrt.truth_option(item) {
		println('yes')
	}
	println(if !pyrt.truth_option(item) { 'True' } else { 'False' })
	println(if !pyrt.truth_option(alias) { 'True' } else { 'False' })
	for pyrt.truth_option(item) {
		println('loop')
		break
	}
	if pyrt.truth_option(maybe(value)) {
		println('call')
	}
	println(if !pyrt.truth_option(maybe(value)) { 'True' } else { 'False' })
	if pyrt.truth_option(maybe_object(value)) {
		println('object call')
	}
}

fn main() {
	report(pyrt.none_)
	report(0)
	report('')
	report('text')
	report(pyrt.empty_list())
	report(pyrt.box([pyrt.box(1)]))
}
