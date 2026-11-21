module main

fn at(text string, index int) string {
	return py2v_string_index1(text, index, none) or { panic(err) }
}

fn py2v_string_index1(value string, index i64, index_error ?IError) !string {
	chars := value.runes()
	offset := if index < 0 { i64(chars.len) + index } else { index }
	if offset < 0 || offset >= i64(chars.len) {
		return index_error or { error('IndexError: string index out of range') }
	}
	return chars[int(offset)].str()
}

fn main() {
	word := 'aé😀'
	println('${at(word, 1)} ${at(word, -1)}')
	println((py2v_string_index1(word, -2, none) or { panic(err) }).str() + ' ' + (py2v_string_index1(word, 2, none) or { panic(err) }).str())
	for char_ in word.runes().reverse().map(it.str()) {
		println(char_)
	}
	for index, char_ in word.split('') {
		println(if char_ == (py2v_string_index1(word, index, none) or { panic(err) }) {
			'True'
		} else {
			'False'
		})
	}
	println(('12'.split('')[1].int()).str() + ' ' + (word.split('')[word.split('').len - 1]).str())
}
