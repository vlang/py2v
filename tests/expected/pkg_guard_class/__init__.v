module py_pkg_guard_class

pub fn total() int {
	saved := choose
	return py2v_integer_add1(int(py2v_integer_add1(read(), saved(7, 2), '__init__.py:7', 'addition')), local_read(), '__init__.py:7', 'addition')
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
