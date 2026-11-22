module main

import pyrt

type Any = pyrt.Value

fn fail_py(value Any) ! {
	pyrt.call_method(pyrt.box(value), 'join', [pyrt.box([1])])!
}

fn py2v_entry1() ! {
	fail_py('')!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
