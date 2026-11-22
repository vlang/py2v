module main

import math

fn main_func() {
	squares := []int{len: 5, init: index}.map(py2v_integer_mul1(it, it, 'list_comprehension.py:3', 'multiplication'))
	println(squares)
	evens := []int{len: 10, init: index}.filter(math.modulo_floored[int](it, 2) == 0).map(it)
	println(evens)
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn main() {
	main_func()
}
