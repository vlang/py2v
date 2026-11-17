module main

fn frozenset(values []int) int {
	return values.len + 20
}

fn main() {
	println(frozenset([1, 2]))
}
