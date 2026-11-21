module main

import pyrt

type Any = pyrt.Value

fn show_py(value Any, enabled bool) ! {
	selected := if enabled { pyrt.item_at(value, pyrt.box(0)) } else { pyrt.none_ }
	println(pyrt.str(selected))
	println(if !!pyrt.truth(selected) { 'True' } else { 'False' })
	println(if !pyrt.truth(selected) { 'True' } else { 'False' })
	if pyrt.truth(selected) {
		println(pyrt.str(pyrt.call_method(pyrt.box(selected), 'upper', [])!))
	}
	println(if pyrt.is_none(selected) { 'True' } else { 'False' })
	scalar := if enabled { pyrt.item_at(value, pyrt.box(0)) } else { pyrt.box('fallback') }
	println(pyrt.str(pyrt.call_method(pyrt.box(scalar), 'upper', [])!))
}

fn py2v_entry1() ! {
	show_py(pyrt.box([pyrt.box('present')]), true)!
	show_py(pyrt.box([pyrt.box('present')]), false)!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
