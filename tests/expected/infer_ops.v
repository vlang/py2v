@[translated]
module main

fn foo() {
	a := 10
	b := 20
	_c1 := (a + b)
	_c2 := (a - b)
	_c3 := (a * b)
	_c4 := (a / b)
	_c5 := -a
	d := 2
	_e1 := (a + d)
	_e2 := (a - d)
	_e3 := (a * d)
	_e4 := (f64(a) / d)
	_f := -3
	_g := -a
}

fn add1(x i8, y i8) i16 {
	return x + y
}

fn add2(x i16, y i16) int {
	return x + y
}

fn add3(x int, y int) i64 {
	return x + y
}

fn add4(x i64, y i64) i64 {
	return x + y
}

fn add5(x u8, y u8) u16 {
	return x + y
}

fn add6(x u16, y u16) u32 {
	return x + y
}

fn add7(x u32, y u32) u64 {
	return x + y
}

fn add8(x u64, y u64) u64 {
	return x + y
}

fn add9(x i8, y u16) u32 {
	return u16(x) + u16(y)
}

fn sub(x i8, y i8) i8 {
	return x - y
}

fn mul(x i8, y i8) i16 {
	return x * y
}

fn fadd1(x i8, y f64) f64 {
	return x + y
}

fn show() {
	assert fadd1(6, 6) == 12
	println('OK')
}

fn main() {
	foo()
	show()
}
