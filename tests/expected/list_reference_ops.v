module main

import pyrt

type Any = pyrt.Value

fn touch_py(values Any) ! {
	pyrt.call_method(pyrt.box(values), 'append', [pyrt.box(3)])!
}

fn touch(values Any) {
	touch_py(values) or { pyrt.fail(err) }
}

fn main_func_py() ! {
	a := pyrt.list_ref[int]([1])
	mut b := a
	b.items << 2
	println('a=${a.items.str()}')
	println((a.items.str()).str() + ' ' + ('${a.items.str()}').str())
	println((if true { 'True' } else { 'False' }).str() + ' ' + (if !!(a.items.len > 0) {
		'True'
	} else {
		'False'
	}).str() + ' ' + (if !(a.items.len > 0) { 'True' } else { 'False' }).str())
	if a.items.len > 0 {
		println('truth')
	}
	println((pyrt.to_int(pyrt.invoke(pyrt.box(a), 'index', pyrt.box(2)))).str() + ' ' + (pyrt.to_int(pyrt.invoke(pyrt.box(a), 'count', pyrt.box(2)))).str())
	c := pyrt.list_ref[int]([7])
	touch_py(pyrt.box(c))!
	println(c.items.str())
	words := pyrt.list_ref[string](['a'])
	mut other := words
	other.items << 'b'
	println(words.items.join(' '))
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
