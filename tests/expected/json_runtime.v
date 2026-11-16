module main

import pyrt.json
import pyrt

fn load_py(text string) !string {
	data := json.loads(text)!
	return json.dumps(pyrt.box(data))!
}

fn load(text string) string {
	return load_py(text) or { pyrt.fail(err) }
}

fn main() {
	println(load('[1, 2.5, \"a\", null, true]'))
}
