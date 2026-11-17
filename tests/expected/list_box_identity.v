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

fn main_func_py() ! {
	mut source := pyrt.list_ref[int]([1])
	records := map[string]Any{
		'list':  pyrt.box(source)
		'label': pyrt.box('kept')
	}
	rows := [pyrt.box(source), pyrt.box(0)]
	source.items << 2
	println((pyrt.length(records['list'])).str() + ' ' + (pyrt.length(rows[0])).str())
	pyrt.call_method(pyrt.box(records['list']), 'append', [pyrt.box(3)])!
	pyrt.call_method(pyrt.box(rows[0]), 'append', [pyrt.box(4)])!
	println(pyrt.str(pyrt.box(source)))
	pyrt.set_index(rows[0], pyrt.box(0), pyrt.box(9))
	println(pyrt.str(pyrt.box(source)))
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
