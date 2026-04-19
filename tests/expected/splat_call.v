module main

fn add(args ...int) int {
	mut total := 0
	for n in args {
		total += n
	}
	return total
}

fn main() {
	nums := [1, 2, 3]
	result := add(...nums)
	println(result)
}
