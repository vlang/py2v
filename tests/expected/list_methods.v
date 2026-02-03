@[translated]
module main

fn main_func() {
	mut nums := [1, 2, 3]
	nums << 4
	println(nums.str())
	nums.insert(0, 0)
	println(nums.str())
	last := nums.pop()
	println(last.str())
	println(nums.str())
	nums.delete(nums.index(2))
	println(nums.str())
	nums << [5, 6, 7]
	println(nums.str())
	nums.clear()
	println(nums.str())
}

fn main() {
	main_func()
}
