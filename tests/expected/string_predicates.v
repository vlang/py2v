module main

fn main_func() {
	println(if ('12345'.len > 0 && '12345'.bytes().all(fn (c u8) bool { return c.is_digit() })) {
		'True'
	} else {
		'False'
	})
	println(if ('hello'.len > 0 && 'hello'.bytes().all(fn (c u8) bool { return c.is_letter() })) {
		'True'
	} else {
		'False'
	})
	println(if ('hello123'.len > 0 && 'hello123'.bytes().all(fn (c u8) bool { return c.is_alnum() })) {
		'True'
	} else {
		'False'
	})
	println(if ('   '.len > 0 && '   '.bytes().all(fn (c u8) bool { return c.is_space() })) {
		'True'
	} else {
		'False'
	})
	println(if 'hello'.is_lower() { 'True' } else { 'False' })
	println(if 'HELLO'.is_upper() { 'True' } else { 'False' })
	println(if 'Hello World'.is_title() { 'True' } else { 'False' })
	println(if ('hello123'.len > 0 && 'hello123'.bytes().all(fn (c u8) bool { return c.is_digit() })) {
		'True'
	} else {
		'False'
	})
	println(if ('hello123'.len > 0 && 'hello123'.bytes().all(fn (c u8) bool { return c.is_letter() })) {
		'True'
	} else {
		'False'
	})
	println(if 'hello'.is_upper() { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
