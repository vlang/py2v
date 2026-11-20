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

fn inspect(v_ Any) {
	println((if pyrt.eq(pyrt.box(v_), pyrt.box(v_)) { 'True' } else { 'False' }).str() + ' ' + (if pyrt.same_object(pyrt.box(v_), pyrt.box(v_)) {
		'True'
	} else {
		'False'
	}).str())
}

fn main() {
	a := pyrt.list_ref[int]([1])
	b := a
	inspect(pyrt.box(a))
	println(b.items.str())
}
