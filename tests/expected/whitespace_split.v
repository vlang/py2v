module main

fn split_text(text string) []string {
	return py2v_split_whitespace1(text)
}

fn main_func() {
	println(split_text('').len)
	println(split_text(' \t\n\r\x0b\x0c\x1c\x1d\x1e\x1f       　').join('|'))
	texts := ['  hello\tworld  ', ' δοκιμή 猫\n', 'abc\x00​def']
	println(split_text(texts[0]).join('|'))
	println(py2v_split_whitespace1(texts[1]).join('|'))
	println(if split_text(texts[2]).join('|') == texts[2] { 'True' } else { 'False' })
	println('a  b '.split(' ').join('|'))
}

fn py2v_split_whitespace1(value string) []string {
	return value.split_any(' \t\n\r\u000b\u000c\u001c\u001d\u001e\u001f\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000').filter(it != '')
}

fn main() {
	main_func()
}
