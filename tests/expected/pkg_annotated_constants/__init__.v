module py_pkg_annotated_constants

pub type Index = int

pub const base = 3

pub const flags = [py2v_integer_left_shift1(1, base, '__init__.py:5')]

pub fn total() int {
	return flags[0]
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_left_shift1(a int, b int, site string) int {
	if b < 0 { panic('ValueError: negative shift count') }
	if a == 0 { return 0 }
	max := int(9223372036854775807)
	min := -max - 1
	if b == 63 && a == -1 { return min }
	if b >= 63 || a > (max >> b) || a < (min >> b) {
		py2v_integer_overflow1(site, 'left shift')
	}
	return a * (int(1) << b)
}
