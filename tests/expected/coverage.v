module main

import strconv

fn inline_pass() {
	// pass
}

fn inline_ellipsis() {
	// ...
}

fn indexing() int {
	mut sum := 0
	mut a := []int{}
	for i in int(0) .. int(10) {
		a << i
		py2v_old1 := sum
		py2v_aug_result2 := py2v_integer_add1(py2v_old1, a[i], 'coverage.py:16', 'addition')
		sum = py2v_aug_result2
	}
	return sum
}

fn infer_bool(code int) bool {
	return code in [1, 2, 4]
}

fn show() {
	mut a1 := 10
	b1 := 15
	b2 := 15
	assert b1 == 15
	assert b2 == 15
	b9 := 2
	b10 := 2
	assert b9 == b10
	a2 := 2.1
	println(py2v_float_text1(a2))
	for i in int(0) .. int(10) {
		println(i)
	}
	py2v_range_start3 := int(0)
	py2v_range_stop4 := int(10)
	py2v_range_step5 := int(2)
	if py2v_range_step5 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start3; if py2v_range_step5 > 0 {
		i < py2v_range_stop4
	} else {
		i > py2v_range_stop4
	}; i = py2v_range_next1(i, py2v_range_stop4, py2v_range_step5) {
		println(i)
	}
	a3 := -a1
	a4 := a3 + a1
	println(a4)
	t1 := if a1 > 5 { 10 } else { 5 }
	assert t1 == 10
	sum1 := indexing()
	println(sum1)
	a5 := [1, 2, 3]
	println(a5.len)
	a9 := ['a', 'b', 'c', 'd']
	println(a9.len)
	a7 := {
		'a': 1
		'b': 2
	}
	println(a7.len)
	a8 := true
	if a8 {
		println('true')
	} else if a4 > 0 {
		println('never get here')
	}
	if a1 == 11 {
		println('false')
	} else {
		println('true')
	}
	if 1 != 0 {
		println('World is sane')
	}
	println(if true { 'True' } else { 'False' })
	if true {
		a1 += 1
	}
	assert a1 == 11
	if true {
		println('true')
	}
	inline_pass()
	s := '1    2'
	println(s)
	assert infer_bool(1)
	escape_quotes_ := ' foo \"bar\" baz '
	assert 'aaabbccc'.contains('bbc')
	assert !!(1 != 0)
	c1_, _, c2_ := 1, 2, 3
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

fn py2v_float_text1[T](value T) string {
	$if T is $float {
		scientific := strconv.f64_to_str(f64(value), 16)
		marker := scientific.index('e') or { return scientific.trim_left('+') }
		exponent := scientific[marker + 1..].int()
		if exponent < -4 || exponent >= 16 {
			return scientific
		}
		sign := if scientific.starts_with('-') { '-' } else { '' }
		digits := scientific[sign.len..marker].replace('.', '')
		point := exponent + 1
		if point <= 0 {
			return sign + '0.' + '0'.repeat(-point) + digits
		}
		if point >= digits.len {
			return sign + digits + '0'.repeat(point - digits.len) + '.0'
		}
		return sign + digits[..point] + '.' + digits[point..]
	} $else {
		return value.str()
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
	show()
}
