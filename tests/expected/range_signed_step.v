module main

fn descending(start int, stop int, step int) {
	py2v_range_start1 := start
	py2v_range_stop2 := stop
	py2v_range_step3 := step
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value := py2v_range_start1; if py2v_range_step3 > 0 {
		value < py2v_range_stop2
	} else {
		value > py2v_range_stop2
	}; value = py2v_range_next1(value, py2v_range_stop2, py2v_range_step3) {
		println(value)
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
	descending(7, -1, -3)
	descending(1, 7, -2)
	py2v_range_start4 := 0
	py2v_range_stop5 := 8
	py2v_range_step6 := 3
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value := py2v_range_start4; if py2v_range_step6 > 0 {
		value < py2v_range_stop5
	} else {
		value > py2v_range_stop5
	}; value = py2v_range_next1(value, py2v_range_stop5, py2v_range_step6) {
		println(value)
	}
	py2v_range_start7 := 0
	py2v_range_stop8 := -2
	py2v_range_step9 := 1
	if py2v_range_step9 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value := py2v_range_start7; if py2v_range_step9 > 0 {
		value < py2v_range_stop8
	} else {
		value > py2v_range_stop8
	}; value = py2v_range_next1(value, py2v_range_stop8, py2v_range_step9) {
		println(value)
	}
}
