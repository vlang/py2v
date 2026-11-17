module main

import pyrt

fn integer(a int, b int) int {
	return py2v_divmod_int1(a, b)[0] * 10 + py2v_divmod_int1(a, b)[1]
}

fn floating(a f64, b f64) f64 {
	py2v_unpack1 := py2v_divmod_float1(a, b)
	mut q := py2v_unpack1[0]
	mut r := py2v_unpack1[1]
	return q * 10 + r
}

fn argument(value int) int {
	println(value)
	return value
}

fn py2v_divmod_int1[A, B](a A, b B) []int {
	left := pyrt.box(a)
	right := pyrt.box(b)
	q := pyrt.floordiv(left, right) or { panic(err) }
	r := pyrt.mod(left, right) or { panic(err) }
	return [pyrt.to_int(q), pyrt.to_int(r)]
}

fn py2v_divmod_float1[A, B](a A, b B) []f64 {
	left := pyrt.box(a)
	right := pyrt.box(b)
	q := pyrt.floordiv(left, right) or { panic(err) }
	r := pyrt.mod(left, right) or { panic(err) }
	return [pyrt.to_float(q), pyrt.to_float(r)]
}

fn main() {
	println(integer(7, 3))
	println(integer(-7, 3))
	println(integer(7, -3))
	println(floating(7.5, 2))
	result := py2v_divmod_int1(argument(7), argument(3))
	println(result[0])
	println(result[1])
}
