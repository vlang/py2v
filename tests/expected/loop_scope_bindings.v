module main

fn annotated() int {
	mut value := 10
	for value_ in [2, 4] {
		value = value_
		println(value_)
	}
	return value
}

fn shadow(values ...int) int {
	mut result := 0
	for values_ in values {
		result = py2v_integer_add1(result, values_, 'loop_scope_bindings.py:11', 'addition')
	}
	return result
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
	println(annotated())
	println(shadow(2, 3))
}
