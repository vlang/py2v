module main

const py2v_branch_736372697074_1 = if check(1) {
	0
} else {
	if check(2) {
		1
	} else {
		if check(3) { 2 } else { 3 }
	}
}

const choose = if py2v_branch_736372697074_1 == 0 {
	py2v_branch_736372697074_2
} else {
	if py2v_branch_736372697074_1 == 1 {
		py2v_branch_736372697074_3
	} else {
		if py2v_branch_736372697074_1 == 2 {
			py2v_branch_736372697074_4
		} else {
			py2v_branch_736372697074_5
		}
	}
}

fn check(which int) bool {
	println(which)
	return which == 2
}

fn py2v_branch_736372697074_2(value int) int {
	return py2v_integer_add1(value, 10, 'module_branch_chain.py:8', 'addition')
}

fn py2v_branch_736372697074_3(value int) int {
	return py2v_integer_add1(value, 20, 'module_branch_chain.py:11', 'addition')
}

fn py2v_branch_736372697074_4(value int) int {
	return py2v_integer_add1(value, 30, 'module_branch_chain.py:14', 'addition')
}

fn py2v_branch_736372697074_5(value int) int {
	return py2v_integer_add1(value, 40, 'module_branch_chain.py:17', 'addition')
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

fn main() {
	previous := choose
	println(choose(1))
	println(previous(2))
}
