module main

import os
import pyrt.pyos

fn show() {
	pyos.putenv('PY2V_SET_A', 'one')
	println(pyos.environ_item('PY2V_SET_A'))
	println(if pyos.environ_has('PY2V_SET_A') { 'True' } else { 'False' })
	pyos.unsetenv('PY2V_SET_A')
	println((if pyos.environ_has('PY2V_SET_A') { 'True' } else { 'False' }).str() + ' ' + (if !pyos.environ_has('PY2V_SET_A') {
		'True'
	} else {
		'False'
	}).str())
	println(pyos.environ_setdefault('PY2V_SET_B', 'two'))
	println(pyos.environ_setdefault('PY2V_SET_B', 'three'))
	println(if pyos.getenv('PY2V_SET_B') == none { 'True' } else { 'False' })
	pyos.environ_delete('PY2V_SET_B')
	println(if pyos.getenv('PY2V_SET_B') == none { 'True' } else { 'False' })
	mut env := pyos.environ()
	env['PY2V_SET_C'] = '1'
	println((env['PY2V_SET_C']).str() + ' ' + (if pyos.environ_has('PY2V_SET_C') {
		'True'
	} else {
		'False'
	}).str())
	other := pyos.environ()
	println((if ('PY2V_SET_C' in other) { 'True' } else { 'False' }).str() + ' ' + (if other.len > 0 {
		'True'
	} else {
		'False'
	}).str())
}

fn main() {
	show()
}
