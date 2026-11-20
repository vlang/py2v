module main

import pyrt

type Any = pyrt.Value

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
