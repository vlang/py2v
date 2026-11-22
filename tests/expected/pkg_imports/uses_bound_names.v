module py_pkg_imports

import py_pkg_imports_sub

pub fn bound_names_total() int {
	return py2v_integer_add1(int(py2v_integer_add1(int(py2v_integer_add1(int(py2v_integer_add1(int(py2v_integer_add1(alpha(), py_pkg_imports_sub.leaf_value(), 'uses_bound_names.py:10', 'addition')), py_pkg_imports_sub.leaf_value(), 'uses_bound_names.py:10', 'addition')), alpha(), 'uses_bound_names.py:10', 'addition')), py_pkg_imports_sub.leaf_value(), 'uses_bound_names.py:10', 'addition')), py_pkg_imports_sub.leaf_value(), 'uses_bound_names.py:10', 'addition')
}

pub fn shadow_module(helper_module int) int {
	return py2v_integer_add1(helper_module, 1, 'uses_bound_names.py:16', 'addition')
}

pub fn shadow_import() int {
	last := 4
	return last
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}
