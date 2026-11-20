module main

fn for_with_break() {
	py2v_range_start1 := 0
	py2v_range_stop2 := 4
	py2v_range_step3 := 1
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		if i == 2 {
			break
		}
		println(i)
	}
}

fn for_with_continue() {
	py2v_range_start4 := 0
	py2v_range_stop5 := 4
	py2v_range_step6 := 1
	if py2v_range_step6 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start4; if py2v_range_step6 > 0 {
		i < py2v_range_stop5
	} else {
		i > py2v_range_stop5
	}; i = py2v_range_next1(i, py2v_range_stop5, py2v_range_step6) {
		if i == 2 {
			continue
		}
		println(i)
	}
}

fn for_with_else() {
	has_break := false
	py2v_range_start7 := 0
	py2v_range_stop8 := 4
	py2v_range_step9 := 1
	if py2v_range_step9 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start7; if py2v_range_step9 > 0 {
		i < py2v_range_stop8
	} else {
		i > py2v_range_stop8
	}; i = py2v_range_next1(i, py2v_range_stop8, py2v_range_step9) {
		println(i)
	}
	if has_break != true {
		println('OK')
	}
}

fn while_with_break() {
	mut i := 0
	for {
		if i == 2 {
			break
		}
		println(i)
		i += 1
	}
}

fn while_with_continue() {
	mut i := 0
	for i < 5 {
		i += 1
		if i == 2 {
			continue
		}
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
	for_with_break()
	for_with_continue()
	for_with_else()
	while_with_break()
	while_with_continue()
}
