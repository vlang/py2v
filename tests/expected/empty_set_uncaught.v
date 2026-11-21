module main

import pyrt

fn fail_py() ! {
	values := pyrt.box(pyrt.new_set([])!)
	pyrt.call_method(pyrt.box(values), 'append', [pyrt.box(1)])!
}

fn py2v_entry1() ! {
	fail_py()!
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}
