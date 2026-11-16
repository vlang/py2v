module main

fn test() int {
	a := [1, 2, 3]
	return a[1]
}

fn main() {
	b := test()
	assert b == 2
	println('OK')
}
