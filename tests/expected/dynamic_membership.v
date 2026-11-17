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

fn contains(value Any, needle string) {
	println(if pyrt.has(value, pyrt.box(needle)) { 'True' } else { 'False' })
	println(if !pyrt.has(value, pyrt.box(needle)) { 'True' } else { 'False' })
}

fn main() {
	contains('abc', 'b')
	contains(pyrt.box([pyrt.box('a'), pyrt.box('c')]), 'b')
	contains(pyrt.box(map[string]Any{
		'b': pyrt.box(1)
	}), 'b')
}
