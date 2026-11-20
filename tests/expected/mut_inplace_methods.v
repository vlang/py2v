module main

import math

fn sorted_copy(values []int) []int {
	mut result := values[..].clone()
	result.sort(a < b)
	return result
}

fn sort_in_place(mut values []int) []int {
	values.sort(a < b)
	return values
}

fn swap_ends(mut values []int) []int {
	values[0], values[values.len - 1] = values[values.len - 1], values[0]
	return values
}

fn drain(mut stack []int) int {
	mut total := 0
	for stack.len > 0 {
		total += stack.pop()
	}
	return total
}

fn group(numbers []int) map[int][]int {
	mut groups := map[int][]int{}
	for number in numbers {
		key := math.modulo_floored(number, 3)
		if (key !in groups) {
			groups[key] = []
		}
		groups[key] << number
	}
	return groups
}

fn collect(prefix int, mut out []int) {
	out << prefix
	if prefix < 3 {
		collect(prefix + 1, mut out)
	}
}

fn gather() []int {
	mut found := []int{}
	collect(1, mut found)
	return found
}

fn main() {
	mut unsorted := [5, 3, 9, 1]
	println(sorted_copy(unsorted))
	println(sort_in_place(mut unsorted))
	mut letters := [4, 5, 6]
	letters.reverse_in_place()
	println(letters)
	println(swap_ends(mut letters))
	mut pending := [1, 2, 3]
	println('${drain(mut pending)} ${pending.len}')
	println(group([1, 2, 3, 4, 5, 6, 7]))
	println(gather())
	mut scratch := [7, 8]
	scratch.clear()
	println(scratch.len)
}
