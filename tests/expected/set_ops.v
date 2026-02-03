@[translated]
module main

fn main_func() {
	a := [1, 2, 3]
	b := [2, 3, 4]
	println(if 1 in a { 'True' } else { 'False' })
	println(if 5 in a { 'True' } else { 'False' })
	@union := (a | b)
	println(@union.str())
	intersection := (a & b)
	println(intersection.str())
	difference := (a - b)
	println(difference.str())
}

fn main() {
	main_func()
}
