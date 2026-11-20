module main

import math
import strconv
import strings

fn py2v_float_text1[T](value T) string {
	$if T is $float {
		scientific := strconv.f64_to_str(f64(value), 16)
		marker := scientific.index('e') or { return scientific.trim_left('+') }
		exponent := scientific[marker + 1..].int()
		if exponent < -4 || exponent >= 16 {
			return scientific
		}
		sign := if scientific.starts_with('-') { '-' } else { '' }
		digits := scientific[sign.len..marker].replace('.', '')
		point := exponent + 1
		if point <= 0 {
			return sign + '0.' + '0'.repeat(-point) + digits
		}
		if point >= digits.len {
			return sign + digits + '0'.repeat(point - digits.len) + '.0'
		}
		return sign + digits[..point] + '.' + digits[point..]
	} $else {
		return value.str()
	}
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
	num := 42
	pi := 3.14
	s := 'hello'
	flag := true
	b := [u8(0x61), 0x62, 0x63]
	c := 1 + math.complex(0.0, 2.0)
	println(num.str() + ' ' + (py2v_float_text1(pi)).str() + ' ' + s.str() + ' ' + (if flag {
		'True'
	} else {
		'False'
	}).str() + ' ' + (py2v_bytes_text1(b)).str() + ' ' + c.str())
}
