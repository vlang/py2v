module main

import math

fn predicate(x int) bool {
	println('predicate ${x}')
	return math.modulo_floored[int](x, 2) == 0
}

fn project(x int) int {
	println('project ${x}')
	return py2v_integer_mul1(x, 10, 'review_w_comprehension_multiple.py:7', 'multiplication')
}

fn main_func() {
	println((fn (py2v_comp_values2 []int) []int {
		mut py2v_comp_output3 := []int{}
		for py2v_comp_item1 in py2v_comp_values2 {
			if !(predicate(py2v_comp_item1)) { continue }
			py2v_comp_output3 << project(py2v_comp_item1)
		}
		return py2v_comp_output3
	})([1, 2, 3, 4]))
	println((fn (py2v_comp_values5 []int) []int {
		mut py2v_comp_output6 := []int{}
		for py2v_comp_item4 in py2v_comp_values5 {
			if !(predicate(py2v_comp_item4)) { continue }
			if !(predicate(py2v_comp_item4 + 1) == false) { continue }
			py2v_comp_output6 << project(py2v_comp_item4)
		}
		return py2v_comp_output6
	})([1, 2, 3, 4]))
	mut py2v_comp1 := []int{}
	for x in [1, 2] {
		for y in [1, 2] {
			if predicate(x + y) {
				py2v_comp1 << project(x + y)
			}
		}
	}
	println(py2v_comp1)
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
