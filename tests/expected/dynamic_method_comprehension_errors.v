module main

import pyrt

type Any = pyrt.Value

fn caught_py(values []Any) ! {
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		result := values.map(pyrt.call_method(pyrt.box(it), 'append', [pyrt.box(1)]) or {
			py2v_err_1 = err
			break py2v_try_1
		})
		println(result.len)
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'AttributeError') != none {
			println('caught')
		} else {
			return py2v_raised_1
		}
	}
}

fn messages_py(values []Any, py2v_comp_err_0 string) ! {
	result := values.map(if pyrt.truth(pyrt.call_method(pyrt.box(it), 'get', [pyrt.box('message')])!) {
		pyrt.item_at(it, pyrt.box('message'))
	} else {
		pyrt.call_method(pyrt.box(it), 'get', [pyrt.box('error'), pyrt.box('')])!
	})
	println(py2v_comp_err_0)
	for value in result {
		println(pyrt.str(value))
	}
}

fn py2v_entry1() ! {
	caught_py([pyrt.empty_list()].map(Any(it)))!
	caught_py([1].map(Any(it)))!
	messages_py([pyrt.box(map[string]Any{
		'message': pyrt.box('one')
	}), pyrt.box(map[string]Any{
		'error': pyrt.box('two')
	})].map(Any(it)), 'pyrt.fail(err)')!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
