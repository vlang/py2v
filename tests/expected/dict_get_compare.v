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

fn compare(data map[string]Any) string {
	return if Any(pyrt.map_get(data, 'x', pyrt.box(0))) > pyrt.box(0) {
		'positive'
	} else {
		'nonpositive'
	}
}

fn main() {
	println(compare(map[string]Any{
		'x': 1
	}))
	println(compare(map[string]Any{}))
}
