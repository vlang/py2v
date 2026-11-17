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

fn show_py(data map[string]Any) ! {
	println(pyrt.str(pyrt.call_method(pyrt.box(Any(pyrt.map_get(data, 'nested', pyrt.empty_dict()))), 'get', [
		pyrt.box('leaf'),
		pyrt.box('empty'),
	])!))
	println(pyrt.str(pyrt.call_method(pyrt.box(Any(pyrt.map_get(data, 'missing', pyrt.empty_dict()))), 'get', [
		pyrt.box('leaf'),
		pyrt.box('empty'),
	])!))
}

fn show(data map[string]Any) {
	show_py(data) or { pyrt.fail(err) }
}

fn main() {
	show(map[string]Any{
		'nested': pyrt.box(map[string]Any{
			'leaf': pyrt.box('found')
		})
	})
}
