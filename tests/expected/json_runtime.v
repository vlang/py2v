module main

import pyrt.json
import pyrt

fn load_py(text string) !string {
	data := json.loads(text)!
	return json.dumps(pyrt.box(data))!
}

fn py2v_entry1() ! {
	println(load_py('[1, 2.5, \"a\", null, true]')!)
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
