module main

import math

fn remainder(a f64, b f64) f64 {
	return py2v_float_mod1(f64(a), f64(b))
}

fn main_func() {
	for a in [-7.5, 7.5, -6, 6, 0, -0] {
		for b in [3, -3] {
			result := remainder(a, b)
			println('${result} ${math.copysign(1, result)}')
		}
	}
	mut value := -7.5
	py2v_old1 := value
	value = py2v_float_mod1(f64(py2v_old1), f64(3))
	println(value)
	println('${py2v_float_mod1(f64(-7), f64(3.5))} ${py2v_float_mod1(f64(7.5), f64(-3))}')
}

fn py2v_float_mod1(a f64, b f64) f64 {
	if b == 0 { panic('float modulo by zero') }
	mut r := math.fmod(a, b)
	if r != 0 {
		if (r < 0) != (b < 0) { r += b }
	} else {
		r = math.copysign(0.0, b)
	}
	return r
}

fn main() {
	main_func()
}
