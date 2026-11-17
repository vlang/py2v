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

fn describe(record Any, mut words []string) int {
	name := pyrt.invoke(record, 'get', pyrt.box('name'), pyrt.box('nobody'))
	tags := pyrt.invoke(record, 'get', pyrt.box('tags'))
	if pyrt.truth(tags) {
		println((pyrt.str(pyrt.invoke(name, 'upper'))).str() + ' ' + (pyrt.length(tags)).str())
	} else {
		println('${pyrt.str(name)} no tags')
	}
	if pyrt.truth(pyrt.invoke(record, 'get', pyrt.box('missing'))) {
		println('unexpected')
	}
	words << 'end'
	for key in pyrt.elements(pyrt.invoke(record, 'keys')) {
		println(pyrt.str(key))
	}
	return words.len
}

fn first_word(text string) Any {
	parts := text.trim_space().split(' ')
	return parts[0]
}

fn count_of(items []int, wanted int) Any {
	return items.count(it == wanted) + 1
}

fn main() {
	println(describe(pyrt.box(map[string]Any{
		'name': pyrt.box('ada')
		'tags': pyrt.box([pyrt.box('x'), pyrt.box('y')])
	}), mut ['a']))
	println(describe(pyrt.box(map[string]Any{
		'tags': pyrt.empty_list()
	}), mut ['a', 'b']))
	println(pyrt.str(first_word('  hello there ')))
	println(pyrt.str(count_of([1, 2, 1], 1)))
}
