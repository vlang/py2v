@[translated]
module main

fn main_func() {
	println(('A'[0]).str())
	println(('Z'[0]).str())
	println(('a'[0]).str())
	println(('0'[0]).str())
	println((rune(65).str()).str())
	println((rune(90).str()).str())
	println((rune(97).str()).str())
	println((rune(48).str()).str())
	c := 'X'
	println((rune(c[0]).str()).str())
}

fn main() {
	main_func()
}
