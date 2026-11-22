module main

fn codepoints(text string) int {
	return text.len_utf8()
}

fn main() {
	text := 'aé😀é'
	println(text.len_utf8())
	println(codepoints(text))
	println(codepoints(''))
	println(['é', '😀'].len)
}
