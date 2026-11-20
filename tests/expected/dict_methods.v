module main

fn main_func() {
	mut d := {
		'a': 1
		'b': 2
		'c': 3
	}
	keys := d.keys().clone()
	println(keys)
	values := d.values().clone()
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
