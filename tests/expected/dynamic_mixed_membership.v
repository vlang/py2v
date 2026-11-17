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

fn contains(value Any, words []string, record map[string]int) {
	println(if pyrt.has(pyrt.box(words), pyrt.box(value)) { 'True' } else { 'False' })
	println(if pyrt.has(pyrt.box(record), pyrt.box(value)) { 'True' } else { 'False' })
	println(if pyrt.has(pyrt.box('abc'), pyrt.box(value)) { 'True' } else { 'False' })
	println(if !pyrt.has(pyrt.box(words), pyrt.box(value)) { 'True' } else { 'False' })
}

fn main() {
	contains('b', ['a', 'c'], map[string]int{
		'b': 1
	})
	contains('c', ['a', 'c'], map[string]int{
		'b': 1
	})
}
