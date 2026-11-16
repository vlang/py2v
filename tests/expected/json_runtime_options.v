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

fn report(names []string, scores map[string]int) string {
	payload := {
		'names': pyrt.box(names)
		'count': pyrt.box(names.len)
	}
	return (json.dumps(pyrt.box(payload), indent: 2) or { panic(err) }) + (json.dumps(pyrt.box(scores),
		sort_keys: true
	) or { panic(err) }) + (json.dumps(pyrt.box(names)) or { panic(err) })
}

fn main() {
	println(report(['b', 'a'], map[string]int{
		'z': 1
		'y': 2
	}))
	println(json.dumps(pyrt.box({
		'a': [pyrt.box(1), pyrt.box(2.5), pyrt.none_, pyrt.box(true)]
	}), separators: [',', ':']) or { panic(err) })
}
