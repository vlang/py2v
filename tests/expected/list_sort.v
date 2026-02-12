@[translated]
module main

fn main_func() {
	nums := [3, 1, 4, 1, 5, 9, 2, 6]
	nums.sort(a < b)
	println(nums.str())
	nums2 := [3, 1, 4, 1, 5, 9, 2, 6]
	nums2.sort(a < b)
	println(nums2.str())
	original := [5, 2, 8, 1, 9]
	sorted_list := (fn (a []Any) []Any {
		mut b := a.clone()
		b.sort()
		return b
	}(original))
	println(original.str())
	println(sorted_list.str())
	items := [1, 2, 3, 4, 5]
	items.reverse()
	println(items.str())
}

fn main() {
	main_func()
}
