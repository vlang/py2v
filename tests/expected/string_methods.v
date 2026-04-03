@[translated]
module main

fn main_func() {
	s := '  hello world  '
	stripped := s.trim_space()
	println(stripped)
	words := 'one,two,three'.split(',')
	println(words)
	joined := ['a', 'b', 'c'].join('-')
	println(joined)
	println('hello'.to_upper())
	println('WORLD'.to_lower())
	replaced := 'hello'.replace('l', 'x')
	println(replaced)
}

fn main() {
	main_func()
}
