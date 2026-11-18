module main

import pyrt.json
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

fn describe_py(record Any, label string) !string {
	summary := {
		'label': pyrt.box(label)
		'name':  pyrt.call_method(pyrt.box(record), 'get', [pyrt.box('name')])!
		'count': pyrt.item_at(record, pyrt.box('count'))
		'tags':  pyrt.box([pyrt.box('a'), pyrt.box('b')])
		'ok':    pyrt.box(true)
	}
	row := [pyrt.box(label), pyrt.item_at(record, pyrt.box('count')),
		pyrt.box(pyrt.to_float(pyrt.box(1.5)))]
	return json.dumps(pyrt.box(summary))! + ' ' + json.dumps(pyrt.box(row))!
}

fn describe(record Any, label string) string {
	return describe_py(record, label) or { pyrt.fail(err) }
}

fn main() {
	println(describe(pyrt.box(map[string]Any{
		'name':  pyrt.box('ada')
		'count': pyrt.box(3)
	}), 'x'))
}
