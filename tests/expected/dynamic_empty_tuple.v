module main

import pyrt

type Any = pyrt.Value

fn read_py(values Any) !Any {
	return pyrt.call_method(pyrt.box(values), 'get', [pyrt.box('items'), pyrt.tuple_of()])!
}

fn read(values Any) Any {
	return read_py(values) or { pyrt.fail(err) }
}

fn main() {
	println(pyrt.str(read(pyrt.box(map[string]Any{
		'items': pyrt.box(5)
	}))))
	println(pyrt.str(read(pyrt.empty_dict())))
}
