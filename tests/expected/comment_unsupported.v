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

fn do_unsupported() {
	a := 1
	(fn () map[string]Any {
		mut result := map[string]Any{}
		for [key, value] in map[string]Any{} {
			result[key + 1] = value + 1
		}
		return result
	}())
	b := (a != 0)
	println(if b { 'True' } else { 'False' })
}

fn main() {
	do_unsupported()
}
