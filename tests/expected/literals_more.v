module main

import strings

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
	n := none
	e := _ // ...
	ba := []u8{}
	println('${n} ${e} ${py2v_bytes_text1(ba)}')
}
