module main

import math

fn squares_above(n int) []int {
	mut py2v_comp1 := []int{}
	for x in 0 .. n {
		y := x * x
		if y > 5 {
			py2v_comp1 << y
		}
	}
	return py2v_comp1
}

fn evens_doubled(nums []int) []int {
	mut py2v_comp2 := []int{}
	for x in nums {
		d := x * 2
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
			w := z * 3
			if w > 6 {
				py2v_comp3 << z
			}
		}
	}
	return py2v_comp3
}

fn main() {
	println(squares_above(8))
	println(evens_doubled([1, 2, 3, 4, 5, 6]))
	println(nested_walrus([[1, 2, 3], [4, 5, 6]]))
}
