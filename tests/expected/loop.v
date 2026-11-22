module main

fn for_with_break() {
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(4)
	py2v_range_step3 := int(1)
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
	py2v_range_start4 := int(0)
	py2v_range_stop5 := int(4)
	py2v_range_step6 := int(1)
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
	py2v_range_start7 := int(0)
	py2v_range_stop8 := int(4)
	py2v_range_step9 := int(1)
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
		i = py2v_integer_add1(i, 1, 'loop.py:28', 'addition')
	}
}

fn while_with_continue() {
	mut i := 0
	for i < 5 {
		i = py2v_integer_add1(i, 1, 'loop.py:34', 'addition')
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
	for_with_break()
	for_with_continue()
	for_with_else()
	while_with_break()
	while_with_continue()
}
