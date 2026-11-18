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

fn main_func() {
	a := pyrt.list_ref[Any]([pyrt.box(1)])
	b := a
	pyrt.invoke(pyrt.box(b), 'append', pyrt.box('x'))
	println(pyrt.str(pyrt.box(a)))
	c := a
	pyrt.invoke(pyrt.box(c), 'append', pyrt.none_)
	println(pyrt.str(pyrt.box(a)))
}

fn main() {
	main_func()
}
