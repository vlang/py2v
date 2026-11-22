module main

import pyrt

// TODO(py2v): no V equivalent for import ctypes
// Provide one in python_to_v_import (types.v) or port the module.

type Any = pyrt.Value

fn foo() {
	a := 10
	b := 20
	c1_ := py2v_integer_add1(a, b, 'infer_ops.py:18', 'addition')
	c2_ := py2v_integer_sub1(a, b, 'infer_ops.py:19', 'subtraction')
	c3_ := py2v_integer_mul1(a, b, 'infer_ops.py:20', 'multiplication')
	c4_ := py2v_true_div1(a, b)
	c5_ := py2v_integer_neg1(a, 'infer_ops.py:22')
	d := 2.0
	e1_ := a + d
	e2_ := a - d
	e3_ := a * d
	e4_ := f64(a) / d
	f_ := -3.0
	g_ := py2v_integer_neg1(a, 'infer_ops.py:29')
}

fn add1(x i8, y i8) Any {
	return py2v_integer_add1(int(x), int(y), 'infer_ops.py:33', 'addition')
}

fn add2(x i16, y i16) Any {
	return py2v_integer_add1(int(x), int(y), 'infer_ops.py:37', 'addition')
}

fn add3(x int, y int) Any {
	return py2v_integer_add1(x, y, 'infer_ops.py:41', 'addition')
}

fn add4(x i64, y i64) Any {
	return py2v_integer_add1(int(x), int(y), 'infer_ops.py:45', 'addition')
}

fn add5(x u8, y u8) Any {
	return int(x) + int(y)
}

fn add6(x u16, y u16) Any {
	return py2v_integer_add1(int(x), int(y), 'infer_ops.py:53', 'addition')
}

fn add7(x u32, y u32) Any {
	return py2v_integer_add1(int(x), int(y), 'infer_ops.py:57', 'addition')
}

fn add8(x u64, y u64) Any {
	return x + y
}

fn add9(x i8, y u16) Any {
	return py2v_integer_add1(int(x), int(y), 'infer_ops.py:65', 'addition')
}

fn sub(x i8, y i8) Any {
	return py2v_integer_sub1(int(x), int(y), 'infer_ops.py:69', 'subtraction')
}

fn mul(x i8, y i8) Any {
	return py2v_integer_mul1(int(x), int(y), 'infer_ops.py:73', 'multiplication')
}

fn fadd1(x i8, y f64) f64 {
	return x + y
}

fn show() {
	assert fadd1(i8(6), 6.0) == 12
	println('OK')
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn py2v_true_div1(a f64, b f64) f64 {
	if b == 0 {
		panic('division by zero')
	}
	return a / b
}

@[inline]
fn py2v_integer_neg1(value int, site string) int {
	if value == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'negation') }
	return -value
}

fn main() {
	foo()
	show()
}
