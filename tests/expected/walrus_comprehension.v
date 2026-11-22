module main

import math

fn squares_above(n int) []int {
	mut py2v_comp1 := []int{}
	for x in 0 .. n {
		y := py2v_integer_mul1(x, x, 'walrus_comprehension.py:7', 'multiplication')
		if y > 5 {
			py2v_comp1 << y
		}
	}
	return py2v_comp1
}

fn evens_doubled(nums []int) []int {
	mut py2v_comp2 := []int{}
	for x in nums {
		d := py2v_integer_mul1(x, 2, 'walrus_comprehension.py:12', 'multiplication')
		if math.modulo_floored[int](d, 4) == 0 {
			py2v_comp2 << d
		}
	}
	return py2v_comp2
}

fn nested_walrus(matrix [][]int) []int {
	mut py2v_comp3 := []int{}
	for row in matrix {
		for z in row {
			w := py2v_integer_mul1(z, 3, 'walrus_comprehension.py:17', 'multiplication')
			if w > 6 {
				py2v_comp3 << z
			}
		}
	}
	return py2v_comp3
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
	println(squares_above(8))
	println(evens_doubled([1, 2, 3, 4, 5, 6]))
	println(nested_walrus([[1, 2, 3], [4, 5, 6]]))
}
