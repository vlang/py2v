module main

import pyrt

type Any = pyrt.Value

fn record() map[string]Any {
	println('receiver evaluated')
	return {
		'present': 'hello'
	}
}

fn main_func() {
	println(pyrt.str(Any(pyrt.map_get(record(), 'present', pyrt.none_))))
	println(pyrt.str(Any(pyrt.map_get(record(), 'missing', pyrt.none_))))
}

fn main() {
	main_func()
}
