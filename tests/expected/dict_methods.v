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
	popped := py2v_native_map_pop1(mut d, 'b')
	println(popped)
	println(d)
	d['x'] = 10
	d['y'] = 20
	println(d)
}

fn py2v_native_map_pop1[K, T](mut items map[K]T, key K) T {
	value := items[key]
	items.delete(key)
	return value
}

fn main() {
	main_func()
}
