module main

fn grow(mut values []int) []int {
	values << 3
	return values
}

fn main_func() {
	mut values := [1, 2]
	expected := [1, 2, 3]
	assert grow(mut values) == expected
	println(values)
}

fn main() {
	main_func()
}
