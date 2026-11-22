module py_pkg_import_branch

pub struct Label {
}

pub fn (self Label) text() string {
	return 'present'
}

pub fn pick() int {
	return value()
}

pub fn total() string {
	return (py2v_integer_add1(pick(), value(), 'choice.py:24', 'addition')).str() + ' ' + Label{}.text()
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
