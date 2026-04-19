module main

import arrays

fn main_func() {
	nums := [3, 1, 4, 1, 5, 9, 2, 6]
	println(arrays.min(nums) or { panic('!') })
	println(arrays.max(nums) or { panic('!') })
	println(arrays.sum(nums) or { 0 })
	println(arrays.min([10, 20]) or { panic('!') })
	println(arrays.max([10, 20]) or { panic('!') })
	println(arrays.min([5, 3]) or { panic('!') })
	println(arrays.max([5, 3]) or { panic('!') })
}

fn main() {
	main_func()
}
