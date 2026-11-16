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
	println(if ('123'.len > 0 && '123'.bytes().all(fn (c u8) bool { return c.is_digit() })) {
		'True'
	} else {
		'False'
	})
	println(if ('abc'.len > 0 && 'abc'.bytes().all(fn (c u8) bool { return c.is_letter() })) {
		'True'
	} else {
		'False'
	})
	println(if ('abc123'.len > 0 && 'abc123'.bytes().all(fn (c u8) bool { return c.is_alnum() })) {
		'True'
	} else {
		'False'
	})
}

fn main() {
	main_func()
}
