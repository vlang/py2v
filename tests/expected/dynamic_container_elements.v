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

fn list_element_py(rows []Any) ! {
	println(pyrt.str(pyrt.call_method(pyrt.box(pyrt.item_at(rows[0], pyrt.box('name'))), 'strip', [])!))
	name := pyrt.item_at(rows[0], pyrt.box('name'))
	println(pyrt.length(name))
	println(pyrt.str(pyrt.slice_of(name, pyrt.box(1), pyrt.box(3))))
}

fn list_element(rows []Any) {
	list_element_py(rows) or { pyrt.fail(err) }
}

fn dict_element_py(record map[string]Any) ! {
	names := record['names']
	println(pyrt.str(pyrt.call_method(pyrt.box(pyrt.item_at(names, pyrt.box(0))), 'upper', [])!))
	for name in pyrt.elements(names) {
		println(pyrt.str(pyrt.call_method(pyrt.box(name), 'strip', [])!))
	}
}

fn dict_element(record map[string]Any) {
	dict_element_py(record) or { pyrt.fail(err) }
}

fn typed_element(names []string) string {
	return names[0].trim_space()
}

fn main() {
	list_element([pyrt.box(map[string]Any{
		'name': pyrt.box(' ada ')
	})].map(Any(it)))
	dict_element(map[string]Any{
		'names': pyrt.box([pyrt.box(' ada '), pyrt.box(' bob ')])
	})
	println(typed_element([' typed ']))
}
