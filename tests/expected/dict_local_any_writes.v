module main

import pyrt

type Any = pyrt.Value

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
