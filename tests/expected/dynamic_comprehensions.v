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

fn names(rows []Any) {
	println(pyrt.str(pyrt.box(rows.filter(pyrt.truth(pyrt.item_at(it, pyrt.box('name')))).map((pyrt.call_method(pyrt.box(pyrt.item_at(it, pyrt.box('name'))), 'upper', []) or { pyrt.fail(err) })))))
}

fn initials(rows Any) {
	println(pyrt.str(pyrt.box(pyrt.elements(rows).map(pyrt.item_at(it, pyrt.box(0))))))
}

fn main() {
	names([
		pyrt.box(map[string]Any{
			'name': pyrt.box('ada')
		}),
		pyrt.box(map[string]Any{
			'name': pyrt.box('')
		}),
		pyrt.box(map[string]Any{
			'name': pyrt.box('bob')
		}),
	].map(Any(it)))
	initials(pyrt.box([pyrt.box('ada'), pyrt.box('bob')]))
}
