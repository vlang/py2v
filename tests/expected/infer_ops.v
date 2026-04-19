module main

type Any = bool | int | i64 | f64 | string | []u8

fn foo() {
	a := 10
	b := 20
	_c1 := a + b
	_c2 := a - b
	_c3 := a * b
	_c4 := a / b
	_c5 := -a
	d := 2
	_e1 := a + d
	_e2 := a - d
	_e3 := a * d
	_e4 := f64(a) / d
	_f := -3
	_g := -a
}

fn add1(x i8, y i8) Any {
	return x + y
}

fn add2(x i16, y i16) Any {
	return x + y
}

fn add3(x int, y int) Any {
	return x + y
}

fn add4(x i64, y i64) Any {
	return x + y
}

fn add5(x u8, y u8) Any {
	return x + y
}

fn add6(x u16, y u16) Any {
	return x + y
}

fn add7(x u32, y u32) Any {
	return x + y
}

fn add8(x u64, y u64) Any {
	return x + y
}

fn add9(x i8, y u16) Any {
	return x + y
}

fn sub(x i8, y i8) Any {
	return x - y
}

fn mul(x i8, y i8) Any {
	return x * y
}

fn fadd1(x i8, y f64) Any {
	return x + y
}

fn show() {
	assert fadd1(6, 6) == 12
	println('OK')
}

fn main() {
	// import ctypes: no known V equivalent
	foo()
	show()
}
