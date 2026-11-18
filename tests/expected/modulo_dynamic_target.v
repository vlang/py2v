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

fn index() int {
	println('index')
	return 0
}

fn divisor() int {
	println('divisor')
	return 3
}

fn receiver(value Any) Any {
	println('receiver')
	return value
}

fn main_func_py() ! {
	mut values := pyrt.box([pyrt.box(-7)])
	py2v_container1 := pyrt.box(values)
	py2v_index2 := pyrt.box(index())
	py2v_old3 := pyrt.item_at(py2v_container1, py2v_index2)
	pyrt.set_index(py2v_container1, py2v_index2, pyrt.modulo(py2v_old3, pyrt.box(divisor())))
	println(pyrt.str(values))
	parser := argparse.new_parser()
	parser.add_argument(['--value'], value_type: .int_type, default_value: pyrt.box(-7))!
	args := parser.parse_args([])!
	py2v_receiver4 := pyrt.box(receiver(pyrt.box(args)))
	py2v_old5 := pyrt.getattr(py2v_receiver4, 'value') or { pyrt.fail(err) }
	pyrt.setattr(py2v_receiver4, 'value', pyrt.modulo(py2v_old5, pyrt.box(divisor()))) or { pyrt.fail(err) }
	println(int(args.get_int('value')!))
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
