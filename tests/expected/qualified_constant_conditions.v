module main

// TODO(py2v): no V equivalent for import token
// Provide one in python_to_v_import (types.v) or port the module.

fn advance(py2v_kind_in1 int, active bool) int {
	mut kind := py2v_kind_in1
	for (active && kind == token.STRING) {
		kind = py2v_integer_add1(kind, 1, 'qualified_constant_conditions.py:6', 'addition')
	}
	if (kind == token.NUMBER) {
		return kind + 1
	}
	return kind
}

fn follows() int {
	return 1
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
