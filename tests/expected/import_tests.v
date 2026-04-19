module main

type Any = bool | int | i64 | f64 | string | []u8

fn test() Any {
	a := [int(1), 2, 3]
	return a[1]
}

fn main() {
	b := test()
	assert b == 2
	println('OK')
}
