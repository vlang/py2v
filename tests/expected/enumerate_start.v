module main

fn letters() string {
	println('iterable')
	return 'aé'
}

fn offset() int {
	println('start')
	return -2
}

fn total(values []int, start int) int {
	mut result := 0
	py2v_enumerated1 := values
	py2v_enum_start2 := start
	for py2v_enum_index3, v_ in py2v_enumerated1 {
		i := py2v_enum_index3 + py2v_enum_start2
		result += i * v_
	}
	return result
}

fn main() {
	py2v_enumerated4 := letters().split('')
	py2v_enum_start5 := offset()
	for py2v_enum_index6, char_ in py2v_enumerated4 {
		i := py2v_enum_index6 + py2v_enum_start5
		println('${i} ${char_}')
	}
	println(total([10, 20, 30], 4))
	println(total([], 9))
}
