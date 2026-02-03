@[translated]
module main

import arrays

fn main_func() {
	nums := [3, 1, 4, 1, 5, 9, 2, 6]
	println((arrays.min(nums) or { panic('!') }).str())
	println((arrays.max(nums) or { panic('!') }).str())
	println((arrays.sum(nums) or { 0 }).str())
	println((arrays.min([10, 20]) or { panic('!') }).str())
	println((arrays.max([10, 20]) or { panic('!') }).str())
	println((arrays.min([5, 3]) or { panic('!') }).str())
	println((arrays.max([5, 3]) or { panic('!') }).str())
}

fn main() {
	main_func()
}
