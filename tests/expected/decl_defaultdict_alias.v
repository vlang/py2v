module main

import datatypes

fn lookup(values map[int]int) int {
	return values[5]
}

fn main() {
	println(lookup(map[int]int{
		5: 17
	}))
}
