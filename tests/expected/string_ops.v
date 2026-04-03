@[translated]
module main

fn main_func() {
	a := 'Hello'
	b := 'World'
	c := ((a + ' ') + b)
	println(c)
	d := ('ab'.repeat(4))
	println(d)
	e := ('-'.repeat(10))
	println(e)
	println(a.len)
	println(c.len)
	println(c[0])
	println(c[c.len - 1])
}

fn main() {
	main_func()
}
