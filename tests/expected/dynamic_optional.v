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

fn show(items Any, value ?string) {
	pyrt.invoke(items, 'append', pyrt.box(value))
	println(pyrt.str(pyrt.item_at(items, pyrt.box(-1))))
}

fn main() {
	show(pyrt.empty_list(), none)
	show(pyrt.empty_list(), '')
	show(pyrt.empty_list(), 'present')
}
