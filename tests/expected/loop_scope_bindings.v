module main

fn annotated() int {
	mut value := 10
	for value_ in [2, 4] {
		value = value_
		println(value_)
	}
	return value
}

fn shadow(values ...int) int {
	mut result := 0
	for values_ in values {
		result += values_
	}
	return result
}

fn main() {
	println(annotated())
	println(shadow(2, 3))
}
