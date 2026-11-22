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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	py2v_enumerated1 := keys().keys()
	py2v_enum_start2 := offset()
	for py2v_enum_index3, key in py2v_enumerated1 {
		index := py2v_integer_add1(py2v_enum_index3, py2v_enum_start2, 'enumerate_dictionary_start.py:11', 'addition')
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
		index := py2v_integer_add1(py2v_enum_index6, py2v_enum_start5, 'enumerate_dictionary_start.py:15', 'addition')
		println('${index} ${key}')
	}
}
