module main

fn main_func() {
	nums := [1, 2, 3, 4, 5]
	for x in nums.reverse() {
		println(x)
	}
	s := 'hello'
	for c in s.reverse() {
		println(c)
	}
	unsorted := [3, 1, 4, 1, 5]
	for x in unsorted.sorted(a > b) {
		println(x)
	}
}

fn main() {
	main_func()
}
