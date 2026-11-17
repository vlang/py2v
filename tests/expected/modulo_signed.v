module main

import math

fn remainder(a int, b int) int {
	return math.modulo_floored(a, b)
}

fn main_func() {
	for a in [-7, 7, -6, 6, 0] {
		for b in [3, -3] {
			println(remainder(a, b))
		}
	}
	mut value := -7
	py2v_old1 := value
	value = math.modulo_floored(py2v_old1, 3)
	println(value)
	py2v_capture2 := &value
	update := fn [py2v_capture2] () int {
		unsafe {
			py2v_old3 := (*py2v_capture2)
			(*py2v_capture2) = math.modulo_floored(py2v_old3, 3)
		}
		return *py2v_capture2
	}
	println(update())
}

fn main() {
	main_func()
}
