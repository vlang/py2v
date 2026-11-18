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

fn main_func() {
	mut values := map[string]Any{
		'item': pyrt.box('first')
	}
	println(pyrt.str(values['item']))
	values['item'] = 2
	println(pyrt.str(values['item']))
	values['other'] = 'last'
	println((pyrt.str(values['other'])).str() + ' ' + (values.len).str())
}

fn main() {
	main_func()
}
