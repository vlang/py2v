module py_pkg_call_defaults_consumer

import py_pkg_call_defaults

pub fn keyword_mark(value int) int {
	println(value)
	return value
}

pub fn run_keywords() {
	println(py_pkg_call_defaults.greet('Grace', 'Hello'))
	println(py_pkg_call_defaults.configured(5, keyword_mark(9)))
	println(py_pkg_call_defaults.side_effect(keyword_mark(3), 2))
	println(py_pkg_call_defaults.shift(keyword_mark(8), -2))
	println(py_pkg_call_defaults.configured(keyword_mark(4), 7))
	println(py_pkg_call_defaults.combine(keyword_mark(1), keyword_mark(2), 5))
	println(py_pkg_call_defaults.combine(3, keyword_mark(4), 5))
	println(py_pkg_call_defaults.flag_name(false))
}
