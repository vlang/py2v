@[has_globals]
module py_pkg_runtime_binding

__global latest = py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_1

__global saved = py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_1

__global before int

__global after int

pub fn py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_1(value int) int {
	return py2v_integer_add1(value, 10, 'choice.py:2', 'addition')
}

pub fn from_body(value int) int {
	return latest(value)
}

pub fn total() int {
	return py2v_integer_add1(after, saved(1), 'choice.py:21', 'addition')
}

pub fn py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_2(value int) int {
	return py2v_integer_add1(value, 20, 'choice.py:14', 'addition')
}

fn py2v_startup_choice_1() {
	saved = latest
	before = from_body(1)
	println(before)
	if from_body(2) == 12 {
		latest = py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_2
	}
	after = from_body(1)
}

fn init() {
	py2v_startup_choice_1()
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
