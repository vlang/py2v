module main

import strings

fn main_func() {
	println(if '42'.len < 5 { strings.repeat(`0`, 5 - '42'.len) + '42' } else { '42' })
	println(if 'hello'.len < 3 { strings.repeat(`0`, 3 - 'hello'.len) + 'hello' } else { 'hello' })
	println(if 'hi'.len < 6 { 'hi' + strings.repeat(' '[0], 6 - 'hi'.len) } else { 'hi' })
	println(if 'hi'.len < 6 { strings.repeat(' '[0], 6 - 'hi'.len) + 'hi' } else { 'hi' })
	println(if 'hi'.len < 6 { 'hi' + strings.repeat('*'[0], 6 - 'hi'.len) } else { 'hi' })
	println(if 'hi'.len < 6 { strings.repeat('-'[0], 6 - 'hi'.len) + 'hi' } else { 'hi' })
	println(py2v_string_center1('hi', 6, ' '))
	println(py2v_string_center1('hi', 7, '-'))
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
