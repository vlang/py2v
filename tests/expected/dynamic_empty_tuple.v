module main

import pyrt

type Any = pyrt.Value

fn read_py(values Any) !Any {
	return pyrt.call_method(pyrt.box(values), 'get', [pyrt.box('items'), pyrt.tuple_of()])!
}

fn py2v_entry1() ! {
	println(pyrt.str(read_py(pyrt.box(map[string]Any{
		'items': pyrt.box(5)
	}))!))
	println(pyrt.str(read_py(pyrt.empty_dict())!))
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
