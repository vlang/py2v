@[translated]
module main

fn complex_test() {
	c1 := (2 + none)
	c2 := (4 + none)
	c3 := (c1 + c2)
	assert c3 == (6 + none)
	c4 := (c1 + 3)
	assert c4 == (5 + none)
	c5 := (c1 + none)
	assert c5 == (2 + none)
	c6 := (c3 - 2.3)
	assert c6 == (3.7 + none)
}

fn main() {
	complex_test()
	println('OK')
}
