module main

import pyrt

// TODO(py2v): 1 except handler(s) need a V Result equivalent:
//   except KeyError (1 stmt)

type Any = pyrt.Value

fn load(flag bool) Any {
	if flag {
		return pyrt.box(map[string]Any{
			'a': pyrt.box(1)
		})
	}
	return pyrt.box([pyrt.box(1), pyrt.box(2)])
}

fn show(flag bool) {
	mut result := pyrt.none_
	if flag {
		result = load(flag)
	} else {
		result = load(false)
	}
	println(pyrt.str(result))
}

fn show2(flag bool) {
	mut result := pyrt.none_
	if flag {
		result = load(flag)
	} else {
		result = load(false)
	}
	println(pyrt.str(result))
}

fn pick_py(flag bool, record Any) ! {
	mut value := pyrt.none_
	mut extra := pyrt.none_
	value = pyrt.item_at(record, pyrt.box('key'))
	// except handlers are not translated: see the TODO(py2v) note above
	//   except KeyError: 1 statement(s) need an `or { ... }` equivalent
	if flag {
		extra = pyrt.call_method(pyrt.box(record), 'get', [pyrt.box('other')])!
	} else {
		extra = value
	}
	println('${pyrt.str(value)} ${pyrt.str(extra)}')
}

fn py2v_entry1() ! {
	show(true)
	show2(false)
	pick_py(true, pyrt.box(map[string]Any{
		'key': pyrt.box(1)
	}))!
	pick_py(false, pyrt.box(map[string]Any{
		'key': pyrt.box('k')
	}))!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
