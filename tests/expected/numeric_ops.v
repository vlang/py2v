module main

import math

fn main_func() {
	println(math.divide_floored[int](17, 5).quot)
	println(math.divide_floored[int](-17, 5).quot)
	println(17 % 5)
	println(math.modulo_floored[int](-17, 5))
	println(py2v_integer_power1(2, 10, 'numeric_ops.py:11'))
	println(py2v_integer_power1(3, 4, 'numeric_ops.py:12'))
	println(math.pow(f64(2), f64(-1)))
	println(math.pow(f64(10), f64(-2)))
	mut b := 2
	b = py2v_integer_power1(b, 3, 'numeric_ops.py:20')
	println(b)
	a := 100
	println(math.divide_floored[int](a, 7).quot)
	println(math.modulo_floored[int](a, 7))
	println(py2v_integer_power1(a, 2, 'numeric_ops.py:27'))
	mut c := -7
	c = math.divide_floored[int](c, 2).quot
	println(c)
	println(math.divide_floored[int](-5, 2).quot)
	println(math.modulo_floored[int](-5, 2))
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
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

fn py2v_integer_power1(a int, b int, site string) int {
	if b < 0 { panic('py2v_unsupported_integer_power: a negative exponent needs a float result') }
	mut base, mut exponent := a, b
	mut result := 1
	for exponent != 0 {
		if exponent & 1 != 0 {
			result = py2v_integer_mul1(result, base, site, 'power')
		}
		exponent >>= 1
		if exponent != 0 {
			base = py2v_integer_mul1(base, base, site, 'power')
		}
	}
	return result
}

fn main() {
	main_func()
}
