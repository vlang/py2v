module main

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

fn fallback(mut data map[string]Any) string {
	data['present'] = 'changed'
	data['new'] = 'inserted'
	println('default evaluated')
	return 'fallback'
}

fn show(mut data map[string]Any) {
	println(pyrt.str(Any(pyrt.map_get(data, 'present', pyrt.box(fallback(mut data))))))
	println(pyrt.str(Any(pyrt.map_get(data, 'new', pyrt.box(fallback(mut data))))))
}

fn main() {
	show(mut map[string]Any{
		'present': 'old'
	})
}
