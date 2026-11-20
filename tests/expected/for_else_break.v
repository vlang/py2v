module main

fn main_func() {
	mut py2v_broke1 := false
	for x in [1, 2, 3] {
		if x == 2 {
			println('found ${x}')
			py2v_broke1 = true
			break
		}
	}
	if !py2v_broke1 {
		println('missing')
	}
	mut py2v_broke2 := false
	for x in [1, 2, 3] {
		if x == 5 {
			py2v_broke2 = true
			break
		}
	}
	if !py2v_broke2 {
		println('no 5')
	}
	mut py2v_broke10 := false
	py2v_range_start3 := int(0)
	py2v_range_stop4 := int(4)
	py2v_range_step5 := int(1)
	if py2v_range_step5 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start3; if py2v_range_step5 > 0 {
		i < py2v_range_stop4
	} else {
		i > py2v_range_stop4
	}; i = py2v_range_next1(i, py2v_range_stop4, py2v_range_step5) {
		mut py2v_broke9 := false
		py2v_range_start6 := int(0)
		py2v_range_stop7 := int(4)
		py2v_range_step8 := int(1)
		if py2v_range_step8 == 0 { panic('ValueError: range() arg 3 must not be zero') }
		for j := py2v_range_start6; if py2v_range_step8 > 0 {
			j < py2v_range_stop7
		} else {
			j > py2v_range_stop7
		}; j = py2v_range_next1(j, py2v_range_stop7, py2v_range_step8) {
			if j > i {
				py2v_broke9 = true
				break
			}
		}
		if !py2v_broke9 {
			println('inner done ${i}')
		}
		if i == 2 {
			py2v_broke10 = true
			break
		}
	}
	if !py2v_broke10 {
		println('outer done')
	}
	mut n := 5
	mut py2v_broke11 := false
	for n > 0 {
		n -= 1
		if n == 2 {
			println('stopped at ${n}')
			py2v_broke11 = true
			break
		}
	}
	if !py2v_broke11 {
		println('ran out')
	}
	mut k := 0
	for k < 3 {
		k += 1
	}
	println('counted ${k}')
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
