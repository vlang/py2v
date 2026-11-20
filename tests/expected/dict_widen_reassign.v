module main

import pyrt

type Any = pyrt.Value

fn main() {
	mut d := map[string]Any{
		'a': pyrt.box(1)
	}
	println(pyrt.str(pyrt.box(d)))
	d = {
		'b': 'foo'
	}
	println(pyrt.str(pyrt.box(d)))
}
