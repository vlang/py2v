module main

import arrays

fn one() []int {
	println('one')
	return [1, 2, 3]
}

fn two() []int {
	println('two')
	return [4, 5]
}

fn three() []int {
	println('three')
	return [6, 7, 8, 9]
}

fn main() {
	py2v_seq1 := arrays.group(one(), two(), three())
	for py2v_item2 in py2v_seq1 {
		a := py2v_item2[0]
		b := py2v_item2[1]
		c := py2v_item2[2]
		println('${a} ${b} ${c}')
	}
	py2v_zip_first3 := 'é🙂+'.runes().map(it.str())
	py2v_zip_second4 := [2, 3]
	py2v_zip_len5 := if py2v_zip_first3.len < py2v_zip_second4.len {
		py2v_zip_first3.len
	} else {
		py2v_zip_second4.len
	}
	for py2v_zip_index6 in 0 .. py2v_zip_len5 {
		a := py2v_zip_first3[py2v_zip_index6]
		b := py2v_zip_second4[py2v_zip_index6]
		println('${a} ${b}')
	}
}
