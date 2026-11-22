module main

fn main_func() {
	a := 'Hello'
	b := 'World'
	c := a + ' ' + b
	println(c)
	d := 'ab'.repeat(4)
	println(d)
	e := '-'.repeat(10)
	println(e)
	println(a.len_utf8())
	println(c.len_utf8())
	println((py2v_string_index1(c, 0, none) or { panic(err) }))
	println((py2v_string_index1(c, -1, none) or { panic(err) }))
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
	main_func()
}
