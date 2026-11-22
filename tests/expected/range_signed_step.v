module main

fn descending(start int, stop int, step int) {
	py2v_range_start1 := int(start)
	py2v_range_stop2 := int(stop)
	py2v_range_step3 := int(step)
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
	py2v_range_start4 := int(0)
	py2v_range_stop5 := int(8)
	py2v_range_step6 := int(3)
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value := py2v_range_start4; if py2v_range_step6 > 0 {
		value < py2v_range_stop5
	} else {
		value > py2v_range_stop5
	}; value = py2v_range_next1(value, py2v_range_stop5, py2v_range_step6) {
		println(value)
	}
	py2v_range_stop7 := int(-2)
	for value in int(0) .. py2v_range_stop7 {
		println(value)
	}
	py2v_range_start8 := int(9)
	py2v_range_stop9 := int(11)
	py2v_range_step10 := int(2)
	if py2v_range_step10 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value := py2v_range_start8; if py2v_range_step10 > 0 {
		value < py2v_range_stop9
	} else {
		value > py2v_range_stop9
	}; value = py2v_range_next1(value, py2v_range_stop9, py2v_range_step10) {
		println(value)
	}
}
