module main

import pyrt.json
import pyrt

fn load(text string) string {
	data := json.loads(text) or { panic(err) }
	return json.dumps(pyrt.box(data)) or { panic(err) }
}

fn main() {
	println(load('[1, 2.5, \"a\", null, true]'))
}
