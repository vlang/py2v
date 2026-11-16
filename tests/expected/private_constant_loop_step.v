module main

const block_ = 2

const limit = 3

fn walk(n int) int {
	mut total := 0
	for start := 0; start < n; start += block_ {
		total += start
	}
	for start := 0; start < n; start += limit {
		total += start
	}
	return total
}

fn main() {
	println(walk(7))
}
