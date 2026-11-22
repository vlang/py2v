module main

import math

fn show() {
	squares := (fn () map[int]i64 {
		mut result := map[int]i64{}
		for x in []int{len: 5, init: index} {
			result[x] = py2v_integer_mul1(x, x, 'dict_comp.py:6', 'multiplication')
		}
		return result
	}())
	println(squares.len)
	evens := (fn () map[int]i64 {
		mut result := map[int]i64{}
		for x in []int{len: 10, init: index} {
			if math.modulo_floored[int](x, 2) == 0 {
				result[x] = py2v_integer_mul1(x, 2, 'dict_comp.py:10', 'multiplication')
			}
		}
		return result
	}())
	println(evens.len)
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
	show()
}
