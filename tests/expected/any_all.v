@[translated]
module main

fn main_func() {
	println(([false, false, true].any(it)).str())
	println(([false, false, false].any(it)).str())
	println(([true, true, true].any(it)).str())
	println(([true, true, true].all(it)).str())
	println(([true, false, true].all(it)).str())
	println(([false, false, false].all(it)).str())
	nums := [1, 2, 3, 4, 5]
	println((nums.map(it > 3).any(it)).str())
	println((nums.map(it > 0).all(it)).str())
	println((nums.map(it > 3).all(it)).str())
}

fn main() {
	main_func()
}
