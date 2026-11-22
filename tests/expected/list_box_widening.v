module main

import pyrt

type Any = pyrt.Value

fn append_text_py(values Any) ! {
	pyrt.call_method(pyrt.box(values), 'append', [pyrt.box('x')])!
}

fn main_func_py() ! {
	source := pyrt.list_ref[Any]([pyrt.box(1)])
	append_text_py(pyrt.box(source))!
	println(pyrt.str(pyrt.box(source)))
}

fn py2v_entry1() ! {
	main_func_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
