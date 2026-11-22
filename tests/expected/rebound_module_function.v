@[has_globals]
module main

__global latest = py2v_branch_736372697074_1

fn py2v_branch_736372697074_1(value int) int {
	return py2v_integer_add1(value, 10, 'rebound_module_function.py:2', 'addition')
}

fn from_body(value int) int {
	return latest(value)
}

fn py2v_branch_736372697074_2(value int) int {
	return py2v_integer_add1(value, 20, 'rebound_module_function.py:13', 'addition')
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
	saved := latest
	println(from_body(1))
	if from_body(2) == 12 {
		latest = py2v_branch_736372697074_2
	}
	println(from_body(1))
	println(saved(1))
}
