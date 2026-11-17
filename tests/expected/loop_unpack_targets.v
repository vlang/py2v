module main

import arrays

fn zipped() int {
	mut result := 0
	py2v_seq1 := arrays.group([1, 2, 9], [3, 4], [5, 6])
	for py2v_item2 in py2v_seq1 {
		first := py2v_item2[0]
		second := py2v_item2[1]
		third := py2v_item2[2]
		result += first + second + third
	}
	return result
}

fn list_target() int {
	mut result := 0
	py2v_seq3 := [[2, 3], [4, 5]]
	for py2v_item4 in py2v_seq3 {
		first := py2v_item4[0]
		second := py2v_item4[1]
		result += first + second
	}
	return result
}

fn backward() int {
	mut result := 0
	py2v_seq5 := [[1, 2, 3], [4, 5, 6]].reverse()
	for py2v_item6 in py2v_seq5 {
		a := py2v_item6[0]
		b := py2v_item6[1]
		c := py2v_item6[2]
		result = result * 10 + a + b + c
	}
	return result
}

fn main() {
	println(zipped())
	println(list_target())
	println(backward())
}
