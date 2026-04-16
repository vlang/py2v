@[translated]

module main

fn main_func() {
	println([false, false, true].any(it))
	println([false, false, false].any(it))
	println([true, true, true].any(it))
	println([true, true, true].all(it))
	println([true, false, true].all(it))
	println([false, false, false].all(it))
	nums := [1, 2, 3, 4, 5]
	println(nums.map(it > 3).any(it))
	println(nums.map(it > 0).all(it))
	println(nums.map(it > 3).all(it))
}

fn main() {
	main_func()
}
