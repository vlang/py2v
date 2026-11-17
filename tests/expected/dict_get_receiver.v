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
