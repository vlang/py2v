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

fn caught(values []Any) {
	caught_py(values) or { pyrt.fail(err) }
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

fn messages(values []Any, py2v_comp_err_0 string) {
	messages_py(values, py2v_comp_err_0) or { pyrt.fail(err) }
}

fn main() {
	caught([pyrt.empty_list()].map(Any(it)))
	caught([1].map(Any(it)))
	messages([pyrt.box(map[string]Any{
		'message': pyrt.box('one')
	}), pyrt.box(map[string]Any{
		'error': pyrt.box('two')
	})].map(Any(it)), 'pyrt.fail(err)')
}
