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

fn fallback() string {
	println('default evaluated')
	return 'fallback'
}

fn key() string {
	println('key evaluated')
	return 'present'
}

fn show(data map[string]Any) {
	println(pyrt.str(Any(pyrt.map_get(data, key(), pyrt.box(fallback())))))
	println(pyrt.str(Any(pyrt.map_get(data, 'missing', pyrt.box(fallback())))))
}

fn main() {
	show(map[string]Any{
		'present': 'hello'
	})
}
