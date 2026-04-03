@[translated]
module main

fn main_func() {
	mut nums := [1, 2, 3]
	nums << 4
	println(nums)
	nums.insert(0, 0)
	println(nums)
	last := nums.pop()
	println(last)
	println(nums)
	nums.delete(nums.index(2))
	println(nums)
	nums << [5, 6, 7]
	println(nums)
	nums.clear()
	println(nums)
}

fn main() {
	main_func()
}
