@[translated]
module main

fn main_func() {
	nums := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	println((nums[2..5]).str())
	println((nums[..3]).str())
	println((nums[7..]).str())
	println((nums[nums.len - 3..]).str())
	println((nums[..nums.len - 2]).str())
	println((nums[..]).str())
	println((nums[1..]).str())
	println((nums[..]).str())
}

fn main() {
	main_func()
}
