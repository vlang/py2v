module main

fn scaled_copy(source []int, denominator int, scale bool) []int {
	mut values := source.clone()
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(values.len)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for index := py2v_range_start1; if py2v_range_step3 > 0 {
		index < py2v_range_stop2
	} else {
		index > py2v_range_stop2
	}; index = py2v_range_next1(index, py2v_range_stop2, py2v_range_step3) {
		mut py2v_container4 := &values
		py2v_index5 := index
		py2v_old6 := (*py2v_container4)[py2v_index5]
		py2v_aug_result7 := py2v_integer_add1(py2v_old6, 1, 'floor_division_comprehension.py:4', 'addition')
		(*py2v_container4)[py2v_index5] = py2v_aug_result7
	}
	if scale {
		values = values.map(int(py2v_integer_floor_div1(it, denominator, 'floor_division_comprehension.py:6')))
	}
	return values
}

fn squared_quotient(value int, denominator int) int {
	return py2v_integer_floor_div1(int(py2v_integer_power1(value, 2, 'floor_division_comprehension.py:11')), denominator, 'floor_division_comprehension.py:11')
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

@[inline]
fn py2v_integer_floor_div1(a int, b int, site string) int {
	if b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }
	if b == -1 && a == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'floor division') }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return a / b - int(adjust)
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
	entries := [20, -20, i64(8589934593), i64(25769803775)]
	println(scaled_copy(entries, 3, false))
	println(scaled_copy(entries, 3, true))
	println(scaled_copy(entries, -3, true))
	println(entries)
	println(squared_quotient(140000, 3))
}
