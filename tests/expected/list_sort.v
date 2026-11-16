module main

fn main_func() {
	mut nums := [3, 1, 4, 1, 5, 9, 2, 6]
	nums.sort(a < b)
	println(nums)
	mut nums2 := [3, 1, 4, 1, 5, 9, 2, 6]
	nums2.sort(a > b)
	println(nums2)
	original := [5, 2, 8, 1, 9]
	sorted_list := original.sorted()
	println(original)
	println(sorted_list)
	mut items := [1, 2, 3, 4, 5]
	items.reverse_in_place()
	println(items)
}

fn main() {
	main_func()
}
