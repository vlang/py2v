module main

import pyrt

type Any = pyrt.Value

fn append_text_py(values Any) ! {
	pyrt.call_method(pyrt.box(values), 'append', [pyrt.box('x')])!
}

fn append_text(values Any) {
	append_text_py(values) or { pyrt.fail(err) }
}

fn main_func_py() ! {
	source := pyrt.list_ref[Any]([pyrt.box(1)])
	append_text_py(pyrt.box(source))!
	println(pyrt.str(pyrt.box(source)))
}

fn main_func() {
	main_func_py() or { pyrt.fail(err) }
}

fn main() {
	main_func()
}
