@[translated]

module main

fn main_func() {
	d := {
		'a': 1
		'b': 2
		'c': 3
	}
	keys := d.keys()
	println(keys)
	values := d.values()
	println(values)
	mut val := d['a'] or { 0 }
	println(val)
	val = d['z'] or { 99 }
	println(val)
	popped := (d['b'] or { 0 })
	println(popped)
	println(d)
	// d.update() - manually merge dicts
	println(d)
}

fn main() {
	main_func()
}
