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

fn show(data map[string]Any) {
	println(pyrt.str(Any(pyrt.map_get(data, 'missing', pyrt.none_))))
	println(pyrt.str(Any(pyrt.map_get(data, 'present', pyrt.none_))))
	println(pyrt.str(Any(pyrt.map_get(data, 'zero', pyrt.none_))))
	println(if pyrt.is_none(Any(pyrt.map_get(data, 'missing', pyrt.none_))) {
		'absent'
	} else {
		'present'
	})
	println(if pyrt.is_none(Any(pyrt.map_get(data, 'missing', pyrt.none_))) {
		'absent'
	} else {
		'present'
	})
	println(if !pyrt.is_none(Any(pyrt.map_get(data, 'present', pyrt.none_))) {
		'present'
	} else {
		'absent'
	})
	println(if !pyrt.is_none(Any(pyrt.map_get(data, 'zero', pyrt.none_))) {
		'present'
	} else {
		'absent'
	})
	println(pyrt.str(Any(pyrt.map_get(data, 'none', pyrt.box('fallback')))))
	println(pyrt.str(Any(pyrt.map_get(data, 'missing', pyrt.box('fallback')))))
}

fn main() {
	show(map[string]Any{
		'present': pyrt.box('hello')
		'zero':    pyrt.box(0)
		'none':    pyrt.none_
	})
}
