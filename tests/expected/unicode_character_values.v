module main

fn at(text string, index int) string {
	return py2v_string_index1(text, index)
}

fn py2v_string_index1(value string, index int) string {
	chars := value.runes()
	offset := if index < 0 { chars.len + index } else { index }
	return chars[offset].str()
}

fn main() {
	word := 'aé😀'
	println('${at(word, 1)} ${at(word, -1)}')
	println('${py2v_string_index1(word, -2)} ${py2v_string_index1(word, 2)}')
	for char_ in word.runes().reverse().map(it.str()) {
		println(char_)
	}
}
