module main

fn main_func() {
	println(if [false, false, true].any(it) { 'True' } else { 'False' })
	println(if [false, false, false].any(it) { 'True' } else { 'False' })
	println(if [true, true, true].any(it) { 'True' } else { 'False' })
	println(if [true, true, true].all(it) { 'True' } else { 'False' })
	println(if [true, false, true].all(it) { 'True' } else { 'False' })
	println(if [false, false, false].all(it) { 'True' } else { 'False' })
	nums := [1, 2, 3, 4, 5]
	println(if nums.map(it > 3).any(it) { 'True' } else { 'False' })
	println(if nums.map(it > 0).all(it) { 'True' } else { 'False' })
	println(if nums.map(it > 3).all(it) { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
