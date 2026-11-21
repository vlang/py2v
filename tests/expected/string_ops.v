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
	println(a.len)
	println(c.len)
	println(py2v_string_index1(c, 0))
	println(py2v_string_index1(c, -1))
}

fn py2v_string_index1(value string, index int) string {
	chars := value.runes()
	offset := if index < 0 { chars.len + index } else { index }
	return chars[offset].str()
}

fn main() {
	main_func()
}
