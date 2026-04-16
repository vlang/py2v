@[translated]

module main

fn main_func() {
	println('A'[0])
	println('Z'[0])
	println('a'[0])
	println('0'[0])
	println(rune(65))
	println(rune(90))
	println(rune(97))
	println(rune(48))
	c := 'X'
	println(rune(c[0]))
}

fn main() {
	main_func()
}
