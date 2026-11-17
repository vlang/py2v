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

fn fill(status map[string]Any, record Any, text string) {
	pyrt.set_index(status['tasks'], pyrt.box('total'), pyrt.box(3))
	pyrt.set_index(status['tasks'], pyrt.box('names'), pyrt.box([pyrt.box('a'), pyrt.box('b')]))
	pyrt.set_index(record, pyrt.box('count'), pyrt.plus(pyrt.item_at(record, pyrt.box('count')), pyrt.box(1)))
	pyrt.set_index(record, pyrt.box('seen'), pyrt.box(true))
	println((pyrt.str(pyrt.item_at(status['tasks'], pyrt.box('total')))).str() + ' ' + (pyrt.str(pyrt.item_at(record, pyrt.box('count')))).str() + ' ' + (pyrt.str(pyrt.item_at(record, pyrt.box('seen')))).str())
	println('${text[..3]} ${text[1..]} ${text[1..3]}')
	head := pyrt.slice_of(pyrt.item_at(record, pyrt.box('title')), pyrt.none_, pyrt.box(5))
	println('${pyrt.str(head)} ${pyrt.length(head)}')
	println(pyrt.str(pyrt.item_at(pyrt.item_at(status['tasks'], pyrt.box('names')), pyrt.box(0))))
}

fn main() {
	fill(map[string]Any{
		'tasks': pyrt.box(map[string]Any{
			'total': pyrt.box(0)
		})
	}, pyrt.box(map[string]Any{
		'count': pyrt.box(1)
		'title': pyrt.box('hello world')
	}), 'abcdef')
}
