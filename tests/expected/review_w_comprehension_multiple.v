module main

import math

fn predicate(x int) bool {
	println('predicate ${x}')
	return math.modulo_floored[int](x, 2) == 0
}

fn project(x int) int {
	println('project ${x}')
	return x * 10
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

fn main() {
	main_func()
}
