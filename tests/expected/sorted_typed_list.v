module main

import arrays

fn check_polygon(nums []f64) bool {
	sorted_nums := nums.sorted()
	return sorted_nums[sorted_nums.len - 1] < (arrays.sum(sorted_nums[..sorted_nums.len - 1]) or { 0 })
}

fn smallest(items []int) int {
	ordered := items.sorted()
	return ordered[0]
}

fn same_digits(a int, b int) bool {
	return a.str().split('').sorted() == b.str().split('').sorted()
}

fn main_func() {
	println(if check_polygon([6, 10, 5]) { 'True' } else { 'False' })
	println(if check_polygon([3, 7, 13, 2]) { 'True' } else { 'False' })
	values := [5, 3, 9, 1]
	println(values.sorted())
	println(values)
	println(smallest(values))
	words := ['pear', 'apple', 'fig']
	println(words.sorted())
	println(if same_digits(125874, 251748) { 'True' } else { 'False' })
	println(if same_digits(12, 13) { 'True' } else { 'False' })
	println('hello'.split('').sorted())
}

fn main() {
	main_func()
}
