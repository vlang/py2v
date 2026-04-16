@[translated]
module main

fn main_func() {
	x := 5
	println(if 1 < x { 'True' } else { 'False' })
	println(if 0 < x { 'True' } else { 'False' })
	println(if 1 <= x { 'True' } else { 'False' })
	a := 3
	b := 5
	c := 7
	println(if a < b { 'True' } else { 'False' })
	println(if a < b { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
