module main

fn first() int {
	value := 10
	value_2 := 5
	return value + value_2
}

fn second() int {
	value := 1
	return value
}

fn main() {
	println('${first()} ${second()}')
}
