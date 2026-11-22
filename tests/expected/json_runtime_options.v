module main

import pyrt.json
import pyrt

type Any = pyrt.Value

fn report_py(names &pyrt.ListRef[string], scores map[string]int) !string {
	payload := map[string]Any{
		'names': pyrt.box(names)
		'count': pyrt.box(names.items.len)
	}
	return json.dumps(pyrt.box(payload), indent: 2)! + json.dumps(pyrt.box(scores), sort_keys: true)! + json.dumps(pyrt.box(names))!
}

fn py2v_entry1() ! {
	println(report_py(pyrt.list_ref[string](['b', 'a']), map[string]int{
		'z': 1
		'y': 2
	})!)
	println(json.dumps(pyrt.box({
		'a': [pyrt.box(1), pyrt.box(pyrt.to_float(pyrt.box(2.5))), pyrt.none_, pyrt.box(true)]
	}), separators: [',', ':'])!)
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
