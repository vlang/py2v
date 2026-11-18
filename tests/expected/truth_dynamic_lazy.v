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

fn probe(label string) Any {
	println(label)
	return label
}

fn either(value Any) Any {
	return if pyrt.truth(value) { value } else { probe('or-right') }
}

fn both(value Any) Any {
	return if pyrt.truth(value) { probe('and-right') } else { value }
}

fn main() {
	println(pyrt.str(either(0)))
	println(pyrt.str(either('left')))
	println(pyrt.str(both(0)))
	println(pyrt.str(both('left')))
}
