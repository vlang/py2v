module main

import math

fn remainder(a int, b int) int {
	return py2v_integer_mod1(a, b, 'modulo_signed.py:2')
}

fn main_func() {
	for a in [-7, 7, -6, 6, 0] {
		for b in [3, -3] {
			println(remainder(a, b))
		}
	}
	mut value := -7
	py2v_old1 := value
	py2v_aug_result2 := math.modulo_floored[int](py2v_old1, 3)
	value = py2v_aug_result2
	println(value)
	py2v_capture3 := &value
	update := fn [py2v_capture3] () int {
		unsafe {
			py2v_old4 := (*py2v_capture3)
			py2v_aug_result5 := math.modulo_floored[int](py2v_old4, 3)
			(*py2v_capture3) = py2v_aug_result5
		}
		return *py2v_capture3
	}
	println(update())
}

@[inline]
fn py2v_integer_mod1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer modulo by zero') }
	if b == -1 { return 0 }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return if adjust { r + b } else { r }
}

fn main() {
	main_func()
}
