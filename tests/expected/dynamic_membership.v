module main

import pyrt

type Any = pyrt.Value

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
