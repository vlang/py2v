module main

fn main_func() {
	py2v_range_start1 := 0
	py2v_range_stop2 := 3
	py2v_range_step3 := 1
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		println(i)
	}
	py2v_range_start4 := 2
	py2v_range_stop5 := 5
	py2v_range_step6 := 1
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start4; if py2v_range_step6 > 0 {
		i < py2v_range_stop5
	} else {
		i > py2v_range_stop5
	}; i = py2v_range_next1(i, py2v_range_stop5, py2v_range_step6) {
		println(i)
	}
	py2v_range_start7 := 0
	py2v_range_stop8 := 10
	py2v_range_step9 := 2
	if py2v_range_step9 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start7; if py2v_range_step9 > 0 {
		i < py2v_range_stop8
	} else {
		i > py2v_range_stop8
	}; i = py2v_range_next1(i, py2v_range_stop8, py2v_range_step9) {
		println(i)
	}
	py2v_range_start10 := 5
	py2v_range_stop11 := 0
	py2v_range_step12 := -1
	if py2v_range_step12 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start10; if py2v_range_step12 > 0 {
		i < py2v_range_stop11
	} else {
		i > py2v_range_stop11
	}; i = py2v_range_next1(i, py2v_range_stop11, py2v_range_step12) {
		println(i)
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
