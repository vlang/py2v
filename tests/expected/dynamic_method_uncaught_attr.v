module main

import pyrt

type Any = pyrt.Value

fn fail_py(value Any) ! {
	pyrt.call_method(pyrt.box(value), 'append', [pyrt.box(2)])!
}

fn py2v_entry1() ! {
	fail_py(1)!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
