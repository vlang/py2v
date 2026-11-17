module py_pkg_call_defaults_consumer

import py_pkg_call_defaults
import pyrt

pub fn mark_keyword_only(value int) int {
	println('keyword argument ${value}')
	return value
}

pub fn run_keyword_only_defaults() {
	println(py_pkg_call_defaults.keyword_only_defaults(5, 7))
	println(py_pkg_call_defaults.keyword_only_defaults(5, mark_keyword_only(9)))
	println(py_pkg_call_defaults.mixed_keyword_default(2, 3))
	println(py_pkg_call_defaults.mixed_keyword_default(4, 8))
	println(py_pkg_call_defaults.required_keyword_default(1, 2, 5))
	println(py_pkg_call_defaults.required_keyword_default(mark_keyword_only(3), mark_keyword_only(4), 5))
	println(py_pkg_call_defaults.keyword_none_default(pyrt.none_))
	println(py_pkg_call_defaults.keyword_none_default('present'))
	println(py_pkg_call_defaults.keyword_float_default(0.0))
}
