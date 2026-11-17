module main

import flag
import pyrt.argparse
import pyrt

fn separator() string {
	println('separator')
	return '|'
}

fn main_func_py() ! {
	parser := argparse.new_parser(prog: 'join-test')
	parser.add_argument(['words'], nargs: '*')!
	parser.add_argument(['--numbers'], nargs: '*', value_type: .int_type)!
	empty := parser.parse_args([])!
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box(' ')), empty.require('words')!)!))
	args := parser.parse_args(['alpha', 'β'])!
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box(' ')), args.require('words')!)!))
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box(separator())), args.require('words')!)!))
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box('')), args.require('words')!)!))
	one := parser.parse_args(['z'])!
	println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box(' - ')), one.require('words')!)!))
	invalid := parser.parse_args(['--numbers', '1', '2'])!
	mut py2v_err_2 := ?IError(none)
	py2v_try_2: for {
		println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box(' ')), invalid.require('numbers') or {
			py2v_err_2 = err
			break py2v_try_2
		}) or {
			py2v_err_2 = err
			break py2v_try_2
		}))
		break
	}
	if py2v_raised_2 := py2v_err_2 {
		if pyrt.caught(py2v_raised_2, 'TypeError') != none {
			println('type-error')
		} else {
			return py2v_raised_2
		}
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		println(pyrt.to_str(pyrt.join(pyrt.box(pyrt.box(separator())), args.require('missing') or {
			py2v_err_1 = err
			break py2v_try_1
		}) or {
			py2v_err_1 = err
			break py2v_try_1
		}))
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

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
