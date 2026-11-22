module main

import math

fn remainder[T](a T, b T) T {
	return py2v_generic_mod1(a, b, 'modulo_generic.py:7')
}

@[inline]
fn py2v_integer_mod1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer modulo by zero') }
	if b == -1 { return 0 }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return if adjust { r + b } else { r }
}

fn py2v_generic_mod1[T](a T, b T, site string) T {
	$if T is $float {
		if b == 0 { panic('float modulo by zero') }
		mut r := math.fmod(f64(a), f64(b))
		if r != 0 {
			if (r < 0) != (b < 0) { r += f64(b) }
		} else {
			r = math.copysign(0.0, f64(b))
		}
		return T(r)
	} $else $if T is u64 {
		return a % b
	} $else $if T is $int {
		return T(py2v_integer_mod1(int(a), int(b), site))
	} $else {
		return a % b
	}
}

fn main() {
	println('${remainder(-7, 3)} ${remainder(7, -3)}')
	println('${remainder(f64(-7.5), f64(3))} ${remainder(f64(7.5), f64(-3))}')
}
