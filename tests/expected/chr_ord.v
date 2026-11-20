module main

fn main_func() {
	println(int('A'.runes()[0]))
	println(int('Z'.runes()[0]))
	println(int('a'.runes()[0]))
	println(int('0'.runes()[0]))
	println(rune(65))
	println(rune(90))
	println(rune(97))
	println(rune(48))
	c := 'X'
	println(rune(int(c.runes()[0])))
}

fn main() {
	main_func()
}
