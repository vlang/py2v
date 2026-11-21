module main

fn main_func() {
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(3)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		py2v_range_start4 := int(0)
		py2v_range_stop5 := int(3)
		py2v_range_step6 := int(1)
		if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
		for j := py2v_range_start4; if py2v_range_step6 > 0 {
			j < py2v_range_stop5
		} else {
			j > py2v_range_stop5
		}; j = py2v_range_next1(j, py2v_range_stop5, py2v_range_step6) {
			println(i * 3 + j)
		}
	}
	py2v_range_start7 := int(0)
	py2v_range_stop8 := int(5)
	py2v_range_step9 := int(1)
	if py2v_range_step9 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start7; if py2v_range_step9 > 0 {
		i < py2v_range_stop8
	} else {
		i > py2v_range_stop8
	}; i = py2v_range_next1(i, py2v_range_stop8, py2v_range_step9) {
		py2v_range_start10 := int(0)
		py2v_range_stop11 := int(5)
		py2v_range_step12 := int(1)
		if py2v_range_step12 == 0 { panic('ValueError: range() arg 3 must not be zero') }
		for j := py2v_range_start10; if py2v_range_step12 > 0 {
			j < py2v_range_stop11
		} else {
			j > py2v_range_stop11
		}; j = py2v_range_next1(j, py2v_range_stop11, py2v_range_step12) {
			if j == 2 {
				break
			}
			println(i * 10 + j)
		}
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
