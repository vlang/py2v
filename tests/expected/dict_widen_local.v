module main

import pyrt

type Any = pyrt.Value

fn main() {
	mut d := map[string]Any{
		'a': pyrt.box(1)
	}
	println(pyrt.str(d['a']))
	d['b'] = 'hi'
	println((pyrt.str(d['a'])).str() + ' ' + (pyrt.str(d['b'])).str())
	d['a'] = 7
	println(pyrt.str(pyrt.box(d)))
}
