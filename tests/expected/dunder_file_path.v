module main

fn source_name() string {
	return @FILE
}

fn py2v_text_length1(text string) int {
	mut length := 0
	for byte in text {
		if (byte & 0xc0) != 0x80 { length++ }
	}
	return length
}

fn main() {
	path := source_name()
	println(if py2v_text_length1(path) > 0 { 'True' } else { 'False' })
	println(if path.ends_with('.py') || path.ends_with('.v') { 'True' } else { 'False' })
	println(if @FILE == path { 'True' } else { 'False' })
}
