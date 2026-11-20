module main

fn pad(text string, width int, fill string) string {
	return py2v_string_center1(text, width, fill)
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
	println((pad('éà', 5, '🙂')).str() + '|' + (pad('é', 4, '🙂')).str() + '|' + (pad('é', 0, '🙂')).str())
	println(py2v_string_center1('', 3, 'ø'))
}
