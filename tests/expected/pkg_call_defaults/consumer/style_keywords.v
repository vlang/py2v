module py_pkg_call_defaults_consumer

import py_pkg_call_defaults
import pyrt

pub fn run_style_keywords() {
	py_pkg_call_defaults.styled('line', true, map[string]Any{
		'fg':     pyrt.box('red')
		'weight': pyrt.box(2)
	})
	py_pkg_call_defaults.styled('default', false, map[string]Any{
		'suffix': pyrt.none_
	})
	py_pkg_call_defaults.styled('default', true, map[string]Any{})
}
