module main

import strings

fn main_func() {
	println(py2v_zfill1('42', 5))
	println(py2v_zfill1('hello', 3))
	println(if 'hi'.len < 6 { 'hi' + strings.repeat(' '[0], 6 - 'hi'.len) } else { 'hi' })
	println(if 'hi'.len < 6 { strings.repeat(' '[0], 6 - 'hi'.len) + 'hi' } else { 'hi' })
	println(if 'hi'.len < 6 { 'hi' + strings.repeat('*'[0], 6 - 'hi'.len) } else { 'hi' })
	println(if 'hi'.len < 6 { strings.repeat('-'[0], 6 - 'hi'.len) + 'hi' } else { 'hi' })
	println(py2v_string_center1('hi', 6, ' '))
	println(py2v_string_center1('hi', 7, '-'))
}

fn py2v_zfill1(text string, width int) string {
	length := text.len_utf8()
	if width <= length { return text }
	zeros := strings.repeat(`0`, width - length)
	if text.len > 0 && (text[0] == `+` || text[0] == `-`) {
		return text[..1] + zeros + text[1..]
	}
	return zeros + text
}

fn py2v_string_center1(value string, width int, fill string) string {
	if fill.runes().len != 1 {
		panic('TypeError: The fill character must be exactly one character long')
	}
	length := value.runes().len
	if width <= length {
		return value
	}
	padding := width - length
	left := padding / 2 + (padding & width & 1)
	return fill.repeat(left) + value + fill.repeat(padding - left)
}

fn main() {
	main_func()
}
