module main

fn main_func() {
	a := [1, 2, 3]
	b := [2, 3, 4]
	println(if 1 in a { 'True' } else { 'False' })
	println(if 5 in a { 'True' } else { 'False' })
	@union := a | b
	println(@union)
	intersection := a & b
	println(intersection)
	difference := a - b
	println(difference)
}

fn main() {
	main_func()
}
