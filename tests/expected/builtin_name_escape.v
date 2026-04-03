@[translated]
module main

type Any = bool | int | i64 | f64 | string | []u8

fn make_pair(string_ Any, int_ Any) map[string]Any {
	return {
		'name':  string_
		'value': int_
	}
}

fn get_value() int {
	return 42
}

fn main() {
	result := make_pair('hello', 10)
	println(result)
	println(get_value())
}
