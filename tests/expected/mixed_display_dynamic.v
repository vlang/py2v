module main

import pyrt.json
import pyrt

type Any = pyrt.Value

fn describe_py(record Any, label string) !string {
	summary := map[string]Any{
		'label': pyrt.box(label)
		'name':  pyrt.box(pyrt.call_method(pyrt.box(record), 'get', [pyrt.box('name')])!)
		'count': pyrt.box(pyrt.item_at(record, pyrt.box('count')))
		'tags':  pyrt.box([pyrt.box('a'), pyrt.box('b')])
		'ok':    pyrt.box(true)
	}
	row := [pyrt.box(label), pyrt.item_at(record, pyrt.box('count')),
		pyrt.box(pyrt.to_float(pyrt.box(1.5)))]
	return json.dumps(pyrt.box(summary))! + ' ' + json.dumps(pyrt.box(row))!
}

fn py2v_entry1() ! {
	println(describe_py(pyrt.box(map[string]Any{
		'name':  pyrt.box('ada')
		'count': pyrt.box(3)
	}), 'x')!)
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
