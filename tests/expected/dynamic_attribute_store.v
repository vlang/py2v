module main

import flag
import pyrt
import pyrt.argparse

type Any = pyrt.Value

fn receiver(holder Any) Any {
	println('receiver')
	return holder
}

fn assigned() int {
	println('value')
	return 7
}

fn write_py(holder Any) ! {
	py2v_attr_value_14 := pyrt.box(assigned())
	pyrt.setattr(pyrt.box(receiver(holder)), 'number', pyrt.box(py2v_attr_value_14))!
}

fn seed_py(holder Any) ! {
	py2v_attr_value_15 := pyrt.box(map[string]Any{
		'old': pyrt.box(1)
	})
	pyrt.setattr(pyrt.box(holder), 'default_map', pyrt.box(py2v_attr_value_15))!
}

fn merge_py(holder Any, config map[string]Any) ! {
	result := pyrt.empty_dict()
	if pyrt.truth(pyrt.getattr(pyrt.box(holder), 'default_map')!) {
		pyrt.call_method(pyrt.box(result), 'update', [pyrt.getattr(pyrt.box(holder), 'default_map')!])!
	}
	pyrt.call_method(pyrt.box(result), 'update', [pyrt.box(config)])!
	py2v_attr_value_16 := result
	pyrt.setattr(pyrt.box(holder), 'default_map', pyrt.box(py2v_attr_value_16))!
}

fn show_py(holder Any) ! {
	seed_py(holder)!
	write_py(holder)!
	merge_py(holder, map[string]Any{
		'new': 'two'
	})!
	println(pyrt.str(pyrt.getattr(pyrt.box(holder), 'number')!))
	println(pyrt.str(pyrt.item_at(pyrt.getattr(pyrt.box(holder), 'default_map')!, pyrt.box('old'))))
	println(pyrt.str(pyrt.item_at(pyrt.getattr(pyrt.box(holder), 'default_map')!, pyrt.box('new'))))
}

fn py2v_entry1() ! {
	parser := argparse.new_parser(prog: 'attrs')
	args := []string{}
	show_py(pyrt.box(parser.parse_args(args)!))!
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		write_py(7) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'AttributeError') != none {
			println('rejected')
		} else {
			pyrt.fail(py2v_raised_1)
		}
	}
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
