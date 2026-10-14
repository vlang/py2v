module main

// TODO(py2v): no V equivalent for import ctypes
// Provide one in python_to_v_import (types.v) or port the module.

type Any = bool | int | i64 | f64 | string | []u8

fn foo() {
	a := 10
	b := 20
	c1_ := a + b
	c2_ := a - b
	c3_ := a * b
	c4_ := a / b
	c5_ := -a
	d := 2
	e1_ := a + d
	e2_ := a - d
	e3_ := a * d
	e4_ := f64(a) / d
	f_ := -3
	g_ := -a
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
	foo()
	show()
}
