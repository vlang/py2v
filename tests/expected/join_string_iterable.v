module main

import pyrt

type Any = pyrt.Value

fn separator() string {
	println('separator')
	return '|'
}

fn payload() string {
	println('iterable')
	return 'aβ'
}

fn placeholders_py(count int) !string {
	return pyrt.to_str(pyrt.join(pyrt.box(pyrt.box(',')), pyrt.box('?'.repeat(count)))!)
}

fn words() []Any {
	return ['a', 'β']
}

fn invalid_words() []Any {
	return [pyrt.box('a'), pyrt.box(3)]
}

fn py2v_entry1() ! {
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box('aβ'))!))
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box('á😀'))!))
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box(''))!))
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box('')), pyrt.box('aβ'))!))
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box('z'))!))
	println(placeholders_py(3)!)
	println(placeholders_py(0)!)
	println(placeholders_py(-2)!)
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box(separator())), pyrt.box(payload()))!))
	println(['a', 'β'].join('|'))
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box(words()))!))
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box(invalid_words())) or {
			py2v_err_1 = err
			break py2v_try_1
		}))
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'TypeError') != none {
			println('type-error')
		} else {
			pyrt.fail(py2v_raised_1)
		}
	}
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
