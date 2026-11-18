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

fn choose(start int, py2v_LIMIT_in1 int) int {
	mut limit := py2v_LIMIT_in1
	limit += start
	return limit
}

fn total(values ...int) int {
	mut result := 0
	for value in values {
		result += value
	}
	return result
}

fn keywords(options map[string]Any) map[string]Any {
	return options
}

fn main() {
	println(choose(2, 3))
}
