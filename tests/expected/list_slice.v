@[translated]

module main

fn main_func() {
	nums := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	println(nums[2..5])
	println(nums[..3])
	println(nums[7..])
	println(nums[nums.len - 3..])
	println(nums[..nums.len - 2])
	println(nums[..])
	println(nums[1..])
	println(nums[..])
}

fn main() {
	main_func()
}
