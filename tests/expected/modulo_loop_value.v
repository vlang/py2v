module main

import math

fn main_func() {
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(4)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for py2v_range_item4 := py2v_range_start1; if py2v_range_step3 > 0 {
		py2v_range_item4 < py2v_range_stop2
	} else {
		py2v_range_item4 > py2v_range_stop2
	}; py2v_range_item4 = py2v_range_next1(py2v_range_item4, py2v_range_stop2, py2v_range_step3) {
		py2v_ident_5f := py2v_range_item4
		println(math.modulo_floored(py2v_ident_5f - 7, 3))
	}
}

fn py2v_range_next1(current int, stop int, step int) int {
	if step > 0 {
		if u64(step) >= u64(stop) - u64(current) {
			return stop
		}
	} else if u64(0) - u64(step) >= u64(current) - u64(stop) {
		return stop
	}
	return current + step
}

fn main() {
	main_func()
}
