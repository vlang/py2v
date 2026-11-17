module py_pkg_call_defaults_consumer

import py_pkg_call_defaults

pub fn run_float_defaults() {
	println(py_pkg_call_defaults.zero_default(0.0))
	println(py_pkg_call_defaults.unit_default(1.0))
	println(py_pkg_call_defaults.negative_default(-2.0))
	println(py_pkg_call_defaults.negative_zero_default(-0.0))
	py_pkg_call_defaults.float_any_default(0.0)
	py_pkg_call_defaults.int_any_default(0)
	println(py_pkg_call_defaults.zero_default(2.5))
}
