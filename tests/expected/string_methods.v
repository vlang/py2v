@[translated]
module main

fn main_func() {
	s := '  hello world  '
	stripped := s.trim_space()
	println(stripped.str())
	words := 'one,two,three'.split(',')
	println(words.str())
	joined := ['a', 'b', 'c'].join('-')
	println(joined.str())
	println(('hello'.to_upper()).str())
	println(('WORLD'.to_lower()).str())
	replaced := 'hello'.replace('l', 'x')
	println(replaced.str())
}

fn main() {
	main_func()
}
