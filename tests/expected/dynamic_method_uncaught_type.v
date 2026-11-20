module main

import pyrt

type Any = pyrt.Value

fn fail_py(value Any) ! {
	pyrt.call_method(pyrt.box(value), 'join', [pyrt.box([1])])!
}

fn fail(value Any) {
	fail_py(value) or { pyrt.fail(err) }
}

fn main() {
	fail('')
}
