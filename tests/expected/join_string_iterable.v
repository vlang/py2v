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

fn placeholders(count int) string {
	return placeholders_py(count) or { pyrt.fail(err) }
}

fn words() []Any {
	return ['a', 'β']
}

fn invalid_words() []Any {
	return [pyrt.box('a'), pyrt.box(3)]
}

fn main() {
	println(pyrt.to_str((pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box('aβ')) or { pyrt.fail(err) })))
	println(pyrt.to_str((pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box('á😀')) or { pyrt.fail(err) })))
	println(pyrt.to_str((pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box('')) or { pyrt.fail(err) })))
	println(pyrt.to_str((pyrt.join(pyrt.box(pyrt.box('')), pyrt.box('aβ')) or { pyrt.fail(err) })))
	println(pyrt.to_str((pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box('z')) or { pyrt.fail(err) })))
	println(placeholders(3))
	println(placeholders(0))
	println(placeholders(-2))
	println(pyrt.to_str((pyrt.join(pyrt.box(pyrt.box(separator())), pyrt.box(payload())) or { pyrt.fail(err) })))
	println(['a', 'β'].join('|'))
	println(pyrt.to_str((pyrt.join(pyrt.box(pyrt.box('|')), pyrt.box(words())) or { pyrt.fail(err) })))
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
