module main

fn show(values []int) {
	println((py2v_int_tuple_text1(values)).str() + ' ' + (py2v_int_tuple_text1(values)).str() + ' ' + ('${py2v_int_tuple_text1(values)}').str())
}

fn py2v_int_tuple_text1[T](values T) string {
	mut items := []string{cap: values.len}
	for value in values {
		items << value.str()
	}
	trailing := if values.len == 1 { ',' } else { '' }
	return '(' + items.join(', ') + trailing + ')'
}

fn main() {
	pair := [3, -1]
	single := [8]
	show(pair)
	show(single)
	println('${py2v_int_tuple_text1(pair)} ${py2v_int_tuple_text1(single)}')
}
