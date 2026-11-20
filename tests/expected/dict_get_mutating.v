module main

import pyrt

type Any = pyrt.Value

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
