@[translated]
module main

fn main_func() {
	println(('12345'.bytes().all(fn (c u8) bool {
		return c.is_digit()
	})).str())
	println(('hello'.bytes().all(fn (c u8) bool {
		return c.is_letter()
	})).str())
	println(('hello123'.bytes().all(fn (c u8) bool {
		return c.is_alnum()
	})).str())
	println(('   '.bytes().all(fn (c u8) bool {
		return c.is_space()
	})).str())
	println(('hello'.is_lower()).str())
	println(('HELLO'.is_upper()).str())
	println(('Hello World'.is_title()).str())
	println(('hello123'.bytes().all(fn (c u8) bool {
		return c.is_digit()
	})).str())
	println(('hello123'.bytes().all(fn (c u8) bool {
		return c.is_letter()
	})).str())
	println(('hello'.is_upper()).str())
}

fn main() {
	main_func()
}
