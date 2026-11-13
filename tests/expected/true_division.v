module main

import math

fn ratio(part int, whole int) f64 {
	return py2v_true_div1(part, whole)
}

fn py2v_true_div1(a f64, b f64) f64 {
	if b == 0 {
		panic('division by zero')
	}
	return a / b
}

fn main() {
	a := 7
	b := 2
	x := 2.5
	println(py2v_true_div1(a, b))
	println(f64(a) / 2)
	println(f64(7) / 2)
	println(f64(a) / -2)
	println(py2v_true_div1(-a, b))
	println(py2v_true_div1(~a, b))
	println(py2v_true_div1(f64(a + 1), b))
	println(py2v_true_div1(a, f64(b + 1)))
	println(py2v_true_div1(a, b) / f64(b))
	println(math.floor(py2v_true_div1(a, b) / 1))
	println(math.pow(2, py2v_true_div1(a, b)))
	println(py2v_true_div1([1, 2, 3].len, b))
	println(py2v_true_div1(f64(math.powi(b, 3)), a))
	half := py2v_true_div1(a, b)
	println(half + 1)
	println(ratio(1, 4))
	println(f64(a) / x)
	println(x / f64(b))
	println(math.divide_floored(a, b).quot)
	share := fn (a int, b int) int {
		return a / b
	}
	println(int(share(8, 2)))
	whole := fn () int {
		return int(py2v_true_div1([1, 2, 3, 4].len, [5].len))
	}
	println(whole())
	println(f64(a) / 1 / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1) / f64(1))
}
