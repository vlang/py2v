module main

fn codepoints(text string) int {
	return py2v_text_length1(text)
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	text := 'aé😀é'
	println(py2v_text_length1(text))
	println(codepoints(text))
	println(codepoints(''))
	println(['é', '😀'].len)
}
