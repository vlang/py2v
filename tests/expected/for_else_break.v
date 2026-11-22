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
		k = py2v_integer_add1(k, 1, 'for_else_break.py:37', 'addition')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	main_func()
}
