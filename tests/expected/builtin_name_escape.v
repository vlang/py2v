@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

fn make_pair(@string Any, @int Any) map[string]Any {
	return {
		'name': @string
		'value': @int
	}
}

fn get_value() int {
	return 42
}

fn main() {
	result := make_pair('hello', 10)
	println(result.str())
	println((get_value()).str())
}
