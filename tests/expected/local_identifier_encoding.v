module main

fn values() int {
	py2v_ident_d8 := 10
	py2v_ident_d8_ := 2
	py2v_ident_5f_31_5f_38_30_30 := 4
	println('Ø _1_800')
	return py2v_integer_add1(int(py2v_integer_add1(py2v_ident_d8_, py2v_ident_5f_31_5f_38_30_30, 'local_identifier_encoding.py:6', 'addition')), py2v_ident_d8, 'local_identifier_encoding.py:6', 'addition')
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
	println(values())
}
