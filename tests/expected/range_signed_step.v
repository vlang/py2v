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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn py2v_integer_power1(a int, b int, site string) int {
	if b < 0 { panic('py2v_unsupported_integer_power: a negative exponent needs a float result') }
	mut base, mut exponent := a, b
	mut result := 1
	for exponent != 0 {
		if exponent & 1 != 0 {
			result = py2v_integer_mul1(result, base, site, 'power')
		}
		exponent >>= 1
		if exponent != 0 {
			base = py2v_integer_mul1(base, base, site, 'power')
		}
	}
	return result
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
	py2v_range_start7 := int(0)
	py2v_range_stop8 := int(-2)
	py2v_range_step9 := int(1)
	if py2v_range_step9 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value := py2v_range_start7; if py2v_range_step9 > 0 {
		value < py2v_range_stop8
	} else {
		value > py2v_range_stop8
	}; value = py2v_range_next1(value, py2v_range_stop8, py2v_range_step9) {
		println(value)
	}
	py2v_range_start10 := int(py2v_integer_power1(3, 2, 'range_signed_step.py:12'))
	py2v_range_stop11 := int(11)
	py2v_range_step12 := int(2)
	if py2v_range_step12 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for value := py2v_range_start10; if py2v_range_step12 > 0 {
		value < py2v_range_stop11
	} else {
		value > py2v_range_stop11
	}; value = py2v_range_next1(value, py2v_range_stop11, py2v_range_step12) {
		println(value)
	}
}
