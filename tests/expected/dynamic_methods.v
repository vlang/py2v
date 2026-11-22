module main

import pyrt

type Any = pyrt.Value

fn describe_py(record Any, mut words []string) !int {
	name := pyrt.call_method(pyrt.box(record), 'get', [pyrt.box('name'), pyrt.box('nobody')])!
	tags := pyrt.call_method(pyrt.box(record), 'get', [pyrt.box('tags')])!
	if pyrt.truth(tags) {
		println((pyrt.str(pyrt.call_method(pyrt.box(name), 'upper', [])!)).str() + ' ' + (pyrt.length(tags)).str())
	} else {
		println('${pyrt.str(name)} no tags')
	}
	if pyrt.truth(pyrt.call_method(pyrt.box(record), 'get', [pyrt.box('missing')])!) {
		println('unexpected')
	}
	words << 'end'
	for key in pyrt.elements(pyrt.call_method(pyrt.box(record), 'keys', [])!) {
		println(pyrt.str(key))
	}
	return words.len
}

fn first_word(text string) Any {
	parts := text.trim_space().split(' ')
	return parts[0]
}

fn count_of(items []int, wanted int) Any {
	return py2v_integer_add1(items.count(it == wanted), 1, 'dynamic_methods.py:25', 'addition')
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn py2v_entry1() ! {
	println(describe_py(pyrt.box(map[string]Any{
		'name': pyrt.box('ada')
		'tags': pyrt.box([pyrt.box('x'), pyrt.box('y')])
	}), mut ['a'])!)
	println(describe_py(pyrt.box(map[string]Any{
		'tags': pyrt.empty_list()
	}), mut ['a', 'b'])!)
	println(pyrt.str(first_word('  hello there ')))
	println(pyrt.str(count_of([1, 2, 1], 1)))
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
