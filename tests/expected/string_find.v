@[translated]
module main

fn main_func() {
	s := 'hello world hello'
	println((s.index('world') or { -1 }).str())
	println((s.index('xyz') or { -1 }).str())
	println((s.count('l')).str())
	println((s.count('hello')).str())
	println((s.starts_with('hello')).str())
	println((s.starts_with('world')).str())
	println((s.ends_with('hello')).str())
	println((s.ends_with('world')).str())
}

fn main() {
	main_func()
}
