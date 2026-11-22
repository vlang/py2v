module main

import pyrt

type Any = pyrt.Value

fn list_element_py(rows []Any) ! {
	println(pyrt.str(pyrt.call_method(pyrt.box(pyrt.item_at(rows[0], pyrt.box('name'))), 'strip', [])!))
	name := pyrt.item_at(rows[0], pyrt.box('name'))
	println(pyrt.length(name))
	println(pyrt.str(pyrt.slice_of(name, pyrt.box(1), pyrt.box(3))))
}

fn dict_element_py(record map[string]Any) ! {
	names := record['names']
	println(pyrt.str(pyrt.call_method(pyrt.box(pyrt.item_at(names, pyrt.box(0))), 'upper', [])!))
	for name in pyrt.elements(names) {
		println(pyrt.str(pyrt.call_method(pyrt.box(name), 'strip', [])!))
	}
}

fn typed_element(names []string) string {
	return names[0].trim_space()
}

fn py2v_entry1() ! {
	list_element_py([pyrt.box(map[string]Any{
		'name': pyrt.box(' ada ')
	})].map(Any(it)))!
	dict_element_py(map[string]Any{
		'names': pyrt.box([pyrt.box(' ada '), pyrt.box(' bob ')])
	})!
	println(typed_element([' typed ']))
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
