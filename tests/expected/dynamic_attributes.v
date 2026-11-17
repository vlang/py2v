module main

import flag
import pyrt
import pyrt.argparse

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

pub struct Label {
pub mut:
	text string = 'known'
}

fn typed_label(value Label) string {
	return value.text.to_upper()
}

fn name_py(value Any) !string {
	return pyrt.to_str(pyrt.invoke(pyrt.getattr(pyrt.box(value), 'label')!, 'upper'))
}

fn name(value Any) string {
	return name_py(value) or { pyrt.fail(err) }
}

fn first_py(value Any) !string {
	return pyrt.to_str(pyrt.item_at(pyrt.getattr(pyrt.box(value), 'words')!, pyrt.box(0)))
}

fn first(value Any) string {
	return first_py(value) or { pyrt.fail(err) }
}

fn words_py(value Any) ! {
	for word in pyrt.elements(pyrt.getattr(pyrt.box(value), 'words')!) {
		println(pyrt.str(pyrt.invoke(word, 'upper')))
	}
}

fn words(value Any) {
	words_py(value) or { pyrt.fail(err) }
}

fn enabled_py(value Any) ! {
	if pyrt.truth(pyrt.getattr(pyrt.box(value), 'enabled')!) {
		println('enabled')
	} else {
		println('disabled')
	}
}

fn enabled(value Any) {
	enabled_py(value) or { pyrt.fail(err) }
}

fn argument() string {
	println('argument')
	return 'x'
}

fn missing_method_py(value Any) ! {
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		pyrt.call(pyrt.getattr(pyrt.box(value), 'missing') or {
			py2v_err_1 = err
			break py2v_try_1
		}, [pyrt.box(argument())]) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'AttributeError') != none {
			println('missing')
		} else {
			return py2v_raised_1
		}
	}
}

fn missing_method(value Any) {
	missing_method_py(value) or { pyrt.fail(err) }
}

fn non_callable_py(value Any) ! {
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		pyrt.call(pyrt.getattr(pyrt.box(value), 'label') or {
			py2v_err_2 = err
			break py2v_try_2
		}, []) or {
			py2v_err_2 = err
			break py2v_try_2
		}
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if pyrt.caught(py2v_raised_2, 'TypeError') != none {
			println('not callable')
		} else {
			return py2v_raised_2
		}
	}
}

fn non_callable(value Any) {
	non_callable_py(value) or { pyrt.fail(err) }
}

fn call_value_py(value Any) ! {
	mut py2v_err_3 := ?IError(none)
	py2v_try_3: for {
		pyrt.call(value, [pyrt.box(argument())]) or {
			py2v_err_3 = err
			break py2v_try_3
		}
		break
	}
	if py2v_raised_3 := py2v_err_3 {
		if pyrt.caught(py2v_raised_3, 'TypeError') != none {
			println('not callable value')
		} else {
			return py2v_raised_3
		}
	}
}

fn call_value(value Any) {
	call_value_py(value) or { pyrt.fail(err) }
}

fn main() {
	parser := argparse.new_parser()
	parser.add_argument(['--label'], default_value: pyrt.box('ada')) or { pyrt.fail(err) }
	parser.add_argument(['--words'], nargs: '*', default_value: pyrt.box(['cat', 'dog'])) or { pyrt.fail(err) }
	parser.add_argument(['--enabled'], action: 'store_true') or { pyrt.fail(err) }
	args := parser.parse_args([]) or { pyrt.fail(err) }
	println(name(pyrt.box(args)))
	println(first(pyrt.box(args)))
	words(pyrt.box(args))
	enabled(pyrt.box(args))
	missing_method(pyrt.box(args))
	non_callable(pyrt.box(args))
	call_value('text')
	println(typed_label(Label{}))
}
