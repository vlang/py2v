module main

fn main_func() {
	s := 'hello world hello'
	println(s.index('world') or { -1 })
	println(s.index('xyz') or { -1 })
	println(s.count('l'))
	println(s.count('hello'))
	println(if s.starts_with('hello') { 'True' } else { 'False' })
	println(if s.starts_with('world') { 'True' } else { 'False' })
	println(if s.ends_with('hello') { 'True' } else { 'False' })
	println(if s.ends_with('world') { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
