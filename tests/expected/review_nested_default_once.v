module main

fn get_number() int {
	println('DEFAULT_EVAL')
	return 8
}

fn run() int {
	py2v_default1 := get_number()
	inner := fn (v_ int) int {
		return v_
	}
	return py2v_integer_add1(inner(py2v_default1), inner(py2v_default1), 'review_nested_default_once.py:7', 'addition')
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
	println(run())
}
