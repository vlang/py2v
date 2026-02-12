@[translated]
module main

fn main_func() {
	d := {
		'a': 1
		'b': 2
		'c': 3
	}
	keys := d.keys()
	println(keys.str())
	values := d.values()
	println(values.str())
	mut val := d['a'] or { 0 }
	println(val.str())
	val = d['z'] or { 99 }
	println(val.str())
	popped := (d['b'] or { 0 })
	println(popped.str())
	println(d.str())
	// d.update() - manually merge dicts
	println(d.str())
}

fn main() {
	main_func()
}
