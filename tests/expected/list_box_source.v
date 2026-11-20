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
	mut rows := []Any{}
	rows << 0
	rows << pyrt.box(source)
	rows << pyrt.box(source)
	source.items << 2
	println('${pyrt.length(rows[1])} ${pyrt.length(rows[2])}')
	pyrt.call_method(pyrt.box(rows[1]), 'append', [pyrt.box(3)])!
	println(source.items.str())
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
