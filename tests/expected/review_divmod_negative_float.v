module main

import pyrt

fn py2v_divmod_float1[A, B](a A, b B) []f64 {
	left := pyrt.box(a)
	right := pyrt.box(b)
	q := pyrt.floordiv(left, right) or { panic(err) }
	r := pyrt.mod(left, right) or { panic(err) }
	return [pyrt.to_float(q), pyrt.to_float(r)]
}

fn main() {
	py2v_unpack1 := py2v_divmod_float1(-4.5, 2)
	mut q := py2v_unpack1[0]
	mut r := py2v_unpack1[1]
	println('${q} ${r}')
}
