module py_pkg_call_defaults_consumer

import py_pkg_call_defaults
import pyrt

pub fn mark() int {
	println('argument evaluated')
	return 3
}

pub fn run() {
	println(py_pkg_call_defaults.greet('Ada', 'Hello'))
	println(py_pkg_call_defaults.shift(8, -2))
	println(py_pkg_call_defaults.configured(5, 7))
	println(py_pkg_call_defaults.optional(pyrt.none_))
	println(py_pkg_call_defaults.side_effect(mark(), 2))
	println(py_pkg_call_defaults.greet('Ada', 'Explicit'))
	println(py_pkg_call_defaults.flag_name(false))
	println(py_pkg_call_defaults.scale_value(1.5))
	run_keywords()
}

pub fn use_main() {
	run()
}
