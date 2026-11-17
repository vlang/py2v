module main

import math

fn remainder[T](a T, b T) T {
	return py2v_generic_mod1(a, b)
}

fn py2v_generic_mod1[T](a T, b T) T {
	$if T is $float {
		if b == 0 { panic('float modulo by zero') }
		mut r := math.fmod(f64(a), f64(b))
		if r != 0 {
			if (r < 0) != (b < 0) { r += f64(b) }
		} else {
			r = math.copysign(0.0, f64(b))
		}
		return T(r)
	} $else $if T is $int {
		return math.modulo_floored(a, b)
	} $else {
		return a % b
	}
}

fn main() {
	println('${remainder(-7, 3)} ${remainder(7, -3)}')
	println('${remainder(f64(-7.5), f64(3))} ${remainder(f64(7.5), f64(-3))}')
}
