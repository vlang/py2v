module main

import strings

fn text() string {
	println('text')
	return '-é🙂'
}

fn width() int {
	println('width')
	return 6
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

fn main() {
	println(py2v_zfill1(text(), width()))
	println(py2v_zfill1('+9', 5))
	println(py2v_zfill1('é', 5))
	println(py2v_zfill1('', 5))
	println(py2v_zfill1('-', 2))
	println(py2v_zfill1('ok', -1))
}
