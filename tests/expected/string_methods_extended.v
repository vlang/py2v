module main

fn main_func() {
	s := 'hello world'
	println(s.capitalize())
	println(s.title())
	lines := 'one\ntwo\nthree'.split_into_lines()
	println(lines)
	tabbed := 'a\tb\tc'
	println(tabbed.expand_tabs(4))
	b := 'hello'.bytes()
	println(b)
	idx := 'hello world'.index('world') or { panic('value not found') }
	println(idx)
	println('banana'.count('a'))
	println(('123'.len > 0 && '123'.bytes().all(fn (c u8) bool {
		return c.is_digit()
	})))
	println(('abc'.len > 0 && 'abc'.bytes().all(fn (c u8) bool {
		return c.is_letter()
	})))
	println(('abc123'.len > 0 && 'abc123'.bytes().all(fn (c u8) bool {
		return c.is_alnum()
	})))
}

fn main() {
	main_func()
}
