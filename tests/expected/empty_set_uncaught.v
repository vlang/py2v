module main

import pyrt

fn fail_py() ! {
	values := pyrt.box(pyrt.new_set([])!)
	pyrt.call_method(pyrt.box(values), 'append', [pyrt.box(1)])!
}

fn fail() {
	fail_py() or { pyrt.fail(err) }
}

fn main() {
	fail()
}
