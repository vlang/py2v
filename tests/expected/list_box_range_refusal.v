module main

import pyrt
import math

type Any = pyrt.Value

fn append_number_py(values Any, number Any) ! {
	pyrt.call_method(pyrt.box(values), 'append', [number])!
}

fn main_func_py() ! {
	source := pyrt.list_ref[int]([1])
	append_number_py(pyrt.box(source), math.powi(2, 40))!
	println(source.items.str())
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
