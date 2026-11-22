module main

import pyrt

type Any = pyrt.Value

fn choose(start int, py2v_LIMIT_in1 int) int {
	mut limit := py2v_LIMIT_in1
	limit += start
	return limit
}

fn total(values ...int) int {
	mut result := 0
	for value in values {
		result = py2v_integer_add1(result, value, 'parameter_bindings.py:9', 'addition')
	}
	return result
}

fn keywords(options map[string]Any) map[string]Any {
	return options
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
	println(choose(2, 3))
}
