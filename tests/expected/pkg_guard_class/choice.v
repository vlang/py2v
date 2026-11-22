module py_pkg_guard_class

pub const py2v_branch_706b675f67756172645f636c6173732e63686f696365_1 = if pick_branch() {
	true
} else {
	false
}

pub const choose = if py2v_branch_706b675f67756172645f636c6173732e63686f696365_1 {
	py2v_branch_706b675f67756172645f636c6173732e63686f696365_2
} else {
	py2v_branch_706b675f67756172645f636c6173732e63686f696365_3
}

pub fn pick_branch() bool {
	return true
}

pub fn py2v_branch_706b675f67756172645f636c6173732e63686f696365_2(left int, right int) int {
	return py2v_integer_sub1(left, right, 'choice.py:7', 'subtraction')
}

pub fn py2v_branch_706b675f67756172645f636c6173732e63686f696365_3(left int, right int) int {
	return py2v_integer_add1(left, right, 'choice.py:10', 'addition')
}

pub fn py2v_nested_706b675f67756172645f636c6173732e63686f696365_1_read() int {
	return 4
}

pub fn local_read() int {
	if true {
		// pass
	}
	return py2v_nested_706b675f67756172645f636c6173732e63686f696365_1_read()
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
}
