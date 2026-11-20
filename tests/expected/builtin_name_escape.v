module main

import pyrt

type Any = pyrt.Value

fn make_pair(string_ string, int_ int) map[string]Any {
	return {
		'name':  pyrt.box(string_)
		'value': pyrt.box(int_)
	}
}

fn get_value() int {
	return 42
}

fn main() {
	result := make_pair('hello', 10)
	println(pyrt.str(pyrt.box(result)))
	println(get_value())
}
