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
	println((a.len).str())
	println((c.len).str())
	println((c[0]).str())
	println((c[c.len - 1]).str())
}

fn main() {
	main_func()
}
