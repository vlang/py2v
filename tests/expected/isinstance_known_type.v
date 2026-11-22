module main

import math

fn trailing_zeros(a int) int {
	if !true {
		// pass
	}
	mut count := 0
	mut rest := a
	for rest > 0 && math.modulo_floored[int](rest, 2) == 0 {
		rest = math.divide_floored[int](int(rest), 2).quot
		count = py2v_integer_add1(count, 1, 'isinstance_known_type.py:8', 'addition')
	}
	return count
}

fn describe(x f64, name string) string {
	if true && true {
		return name + ' is a number'
	}
	return name + ' is not a number'
}

fn is_text(n int) string {
	if false {
		return 'text'
	}
	return 'not text'
}

fn total(items []int) int {
	if !true {
		return -1
	}
	mut result := 0
	for item in items {
		result = py2v_integer_add1(result, item, 'isinstance_known_type.py:29', 'addition')
	}
	return result
}

fn run() {
	values := [int(1), 2, 3]
	println(trailing_zeros(8))
	println(describe(2.5, 'x'))
	println(is_text(4))
	println(total(values))
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
	run()
}
