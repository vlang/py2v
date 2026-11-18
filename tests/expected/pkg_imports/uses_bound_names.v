module py_pkg_imports

import py_pkg_imports_sub

pub fn bound_names_total() int {
	return alpha() + py_pkg_imports_sub.leaf_value() + py_pkg_imports_sub.leaf_value() + alpha() + py_pkg_imports_sub.leaf_value() + py_pkg_imports_sub.leaf_value()
}

pub fn shadow_module(helper_module int) int {
	return helper_module + 1
}

pub fn shadow_import() int {
	last := 4
	return last
}
