@[translated]
module main

fn main_func() {
	println(('12345'.len > 0 && '12345'.bytes().all(fn (c u8) bool {
		return c.is_digit()
	})))
	println(('hello'.len > 0 && 'hello'.bytes().all(fn (c u8) bool {
		return c.is_letter()
	})))
	println(('hello123'.len > 0 && 'hello123'.bytes().all(fn (c u8) bool {
		return c.is_alnum()
	})))
	println(('   '.len > 0 && '   '.bytes().all(fn (c u8) bool {
		return c.is_space()
	})))
	println('hello'.is_lower())
	println('HELLO'.is_upper())
	println('Hello World'.is_title())
	println(('hello123'.len > 0 && 'hello123'.bytes().all(fn (c u8) bool {
		return c.is_digit()
	})))
	println(('hello123'.len > 0 && 'hello123'.bytes().all(fn (c u8) bool {
		return c.is_letter()
	})))
	println('hello'.is_upper())
}

fn main() {
	main_func()
}
