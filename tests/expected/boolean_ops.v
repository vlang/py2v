@[translated]
module main

fn main_func() {
	a := true
	b := false
	println(if a && b { 'True' } else { 'False' })
	println(if a || b { 'True' } else { 'False' })
	println(if !a { 'True' } else { 'False' })
	println(if !b { 'True' } else { 'False' })
	println(if a && a { 'True' } else { 'False' })
	println(if b || b { 'True' } else { 'False' })
	println(if (a || b) && (a || b) { 'True' } else { 'False' })
	println(if !(a && b) { 'True' } else { 'False' })
	x := 5
	println(if x > 0 && x < 10 { 'True' } else { 'False' })
	println(if x < 0 || x > 3 { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
