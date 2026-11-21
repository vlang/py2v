module main

import flag
import pyrt
import pyrt.argparse

type Any = pyrt.Value

pub struct Label {
pub mut:
	text string = 'known'
}

fn (self Label) == (other Label) bool {
	return self.text == other.text
}

fn typed_label(value Label) string {
	return value.text.to_upper()
}

fn name_py(value Any) !string {
	return pyrt.to_str(pyrt.call_method(pyrt.box(pyrt.getattr(pyrt.box(value), 'label')!), 'upper', [])!)
}

fn first_py(value Any) !string {
	return pyrt.to_str(pyrt.item_at(pyrt.getattr(pyrt.box(value), 'words')!, pyrt.box(0)))
}

fn words_py(value Any) ! {
	for word in pyrt.elements(pyrt.getattr(pyrt.box(value), 'words')!) {
		println(pyrt.str(pyrt.call_method(pyrt.box(word), 'upper', [])!))
	}
}

fn enabled_py(value Any) ! {
	if pyrt.truth(pyrt.getattr(pyrt.box(value), 'enabled')!) {
		println('enabled')
	} else {
		println('disabled')
	}
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

fn py2v_entry1() ! {
	parser := argparse.new_parser()
	parser.add_argument(['--label'], default_value: pyrt.box('ada'))!
	parser.add_argument(['--words'], nargs: '*', default_value: pyrt.box(['cat', 'dog']))!
	parser.add_argument(['--enabled'], action: 'store_true')!
	args := parser.parse_args([])!
	println(name_py(pyrt.box(args))!)
	println(first_py(pyrt.box(args))!)
	words_py(pyrt.box(args))!
	enabled_py(pyrt.box(args))!
	missing_method_py(pyrt.box(args))!
	non_callable_py(pyrt.box(args))!
	call_value_py('text')!
	println(typed_label(Label{}))
	println(if Label{} == Label{} { 'True' } else { 'False' })
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
