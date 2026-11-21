module main

fn text() string {
	println('read')
	return ''
}

fn missing(s string) bool {
	return py2v_text_is_none1(s)
}

fn py2v_text_is_none1(value string) bool {
	_ = value
	return false
}

fn main() {
	println(if missing('') { 'True' } else { 'False' })
	println(if !missing(text()) { 'True' } else { 'False' })
	values := ['', 'x']
	println(if missing(values[1]) { 'True' } else { 'False' })
}
