@[translated]
module main

fn main_func() {
	s := 'hello world hello'
	println(s.index('world') or { -1 })
	println(s.index('xyz') or { -1 })
	println(s.count('l'))
	println(s.count('hello'))
	println(s.starts_with('hello'))
	println(s.starts_with('world'))
	println(s.ends_with('hello'))
	println(s.ends_with('world'))
}

fn main() {
	main_func()
}
