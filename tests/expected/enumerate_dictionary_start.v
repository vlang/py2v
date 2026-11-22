module main

fn keys() map[string]int {
	println('iterable')
	return {
		'alpha': 1
		'beta':  2
	}
}

fn offset() int {
	println('start')
	return -3
}

fn main() {
	py2v_enumerated1 := keys().keys()
	py2v_enum_start2 := offset()
	for py2v_enum_index3, key in py2v_enumerated1 {
		index := py2v_enum_index3 + py2v_enum_start2
		println('${index} ${key}')
	}
	for index, key in {
		'one': 1
		'two': 2
	}.keys() {
		println('${index} ${key}')
	}
	py2v_enumerated4 := ['yes', 'no']
	py2v_enum_start5 := int(true)
	for py2v_enum_index6, key in py2v_enumerated4 {
		index := py2v_enum_index6 + py2v_enum_start5
		println('${index} ${key}')
	}
}
