module main

fn main_func() {
	x := 5
	println(if 1 < x && x < 10 { 'True' } else { 'False' })
	println(if 0 < x && x < 3 { 'True' } else { 'False' })
	println(if 1 <= x && x <= 5 { 'True' } else { 'False' })
	a := 3
	b := 5
	c := 7
	println(if a < b && b < c { 'True' } else { 'False' })
	println(if a < b && b > c { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
