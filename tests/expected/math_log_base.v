module main

import math

fn digits(number int, base int) int {
	return py2v_integer_add1(int(math.log_n(number, base)), 1, 'math_log_base.py:6', 'addition')
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
	println(math.round_sig(math.log_n(8, 2), 6))
	println(math.round_sig(math.log_n(1000, 10), 6))
	println('${math.round_sig(math.log(math.e), 6)} ${math.round_sig(math.log(1), 6)}')
	println(digits(1000, 4))
}
