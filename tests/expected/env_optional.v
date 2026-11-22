module main

import os
import pyrt.pyos
import pyrt

fn pick() string {
	a := pyrt.first_text(pyos.getenv('PY2V_UNSET_A'), pyos.getenv('HOME'))
	if a == none {
		return 'none'
	}
	return a
}

fn flag() bool {
	previous := pyos.getenv('PY2V_UNSET_B')
	if previous != none && previous != '' {
		return true
	}
	if pyrt.has_text(pyos.getenv('HOME')) {
		return previous == none
	}
	return false
}

fn named() string {
	name := pyos.getenv('PY2V_UNSET_C')
	return if name != none { name } else { 'unset' }
}

fn fallback() string {
	return pyrt.text_or(pyos.getenv('PY2V_UNSET_D'), 'default')
}

fn chain() string {
	return pyrt.text_or(pyrt.first_text(pyos.getenv('PY2V_UNSET_E'), pyos.getenv('PY2V_UNSET_F')), 'last')
}

fn absent() bool {
	return !pyrt.has_text(pyos.getenv('PY2V_UNSET_G')) && pyos.environ_get('PY2V_UNSET_H', 'x') == 'x'
}

fn main() {
	println(if pick().len_utf8() > 0 { 'True' } else { 'False' })
	println(if flag() { 'True' } else { 'False' })
	println(named())
	println(fallback())
	println(chain())
	println(if absent() { 'True' } else { 'False' })
}
