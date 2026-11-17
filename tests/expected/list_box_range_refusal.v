module main

import pyrt
import math

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

fn append_number_py(values Any, number Any) ! {
	pyrt.call_method(pyrt.box(values), 'append', [number])!
}

fn append_number(values Any, number Any) {
	append_number_py(values, number) or { pyrt.fail(err) }
}

fn main_func_py() ! {
	source := pyrt.list_ref[int]([1])
	append_number_py(pyrt.box(source), math.powi(2, 40))!
	println(pyrt.str(pyrt.box(source)))
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
