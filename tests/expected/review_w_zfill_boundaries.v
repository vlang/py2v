module main

import strings

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
	for s in ['', '1', '+1', '-1', '+', '-', 'é', '-é', 'é', '١٢', '-١٢', '+é', '🙂'] {
		for width in [-1, 0, 1, 3, 5] {
			println('${s} ${width} ${py2v_zfill1(s, width)}')
		}
	}
}
