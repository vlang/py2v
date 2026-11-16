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

fn show(record Any, fallback string) {
	name := pyrt.either(pyrt.invoke(record, 'get', pyrt.box('name')), pyrt.box('nobody'))
	tags := pyrt.either(pyrt.invoke(record, 'get', pyrt.box('tags')), pyrt.empty_list())
	count := pyrt.either(pyrt.item_at(record, pyrt.box('count')), pyrt.box(0))
	date := pyrt.slice_of(pyrt.either(pyrt.invoke(record, 'get', pyrt.box('when')), pyrt.box('')), pyrt.none_, pyrt.box(4))
	owner := pyrt.either(pyrt.invoke(record, 'get', pyrt.box('owner')), pyrt.box(fallback))
	both := pyrt.both(pyrt.invoke(record, 'get', pyrt.box('name')), pyrt.box(fallback))
	println('${pyrt.str(name)} ${pyrt.str(pyrt.length(tags))} ${pyrt.str(count)} ${pyrt.str(date)} ${pyrt.str(owner)} ${pyrt.str(both)}')
	if pyrt.truth(pyrt.invoke(record, 'get', pyrt.box('name'))) || pyrt.truth(pyrt.invoke(record, 'get', pyrt.box('owner'))) {
		println('named')
	}
}

fn main() {
	show(pyrt.box(map[string]Any{
		'name':  pyrt.box('ada')
		'count': pyrt.box(3)
		'when':  pyrt.box('2026-11-16')
	}), 'x')
	show(pyrt.box(map[string]Any{
		'count': pyrt.box(0)
		'tags':  pyrt.box([pyrt.box('a')])
		'owner': pyrt.box('o')
	}), 'y')
	show(pyrt.box(map[string]Any{
		'count': pyrt.box(2)
	}), 'z')
}
