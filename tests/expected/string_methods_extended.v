module main

import strings

fn main_func() {
	s := 'hello world'
	println(s.capitalize())
	println(s.title())
	lines := 'one\ntwo\nthree'.split_into_lines()
	println(lines)
	tabbed := 'a\tb\tc'
	println(tabbed.expand_tabs(4))
	b := 'hello'.bytes()
	println(py2v_bytes_text1(b))
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

fn py2v_bytes_text1(value []u8) string {
	quote := if u8(39) in value && u8(34) !in value { u8(34) } else { u8(39) }
	mut text := strings.new_builder(value.len + 3)
	text.write_u8(98)
	text.write_u8(quote)
	for byte_value in value {
		if byte_value == quote || byte_value == 92 {
			text.write_u8(92)
			text.write_u8(byte_value)
			continue
		}
		match byte_value {
			9 { text.write_string('\\t') }
			10 { text.write_string('\\n') }
			13 { text.write_string('\\r') }
			32...126 { text.write_u8(byte_value) }
			else { text.write_string('\\x' + '${byte_value:02x}') }
		}
	}
	text.write_u8(quote)
	return text.str()
}

fn main() {
	main_func()
}
