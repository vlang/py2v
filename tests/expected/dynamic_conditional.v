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

fn show(value Any, enabled bool) {
	show_py(value, enabled) or { pyrt.fail(err) }
}

fn main() {
	show(pyrt.box([pyrt.box('present')]), true)
	show(pyrt.box([pyrt.box('present')]), false)
}
