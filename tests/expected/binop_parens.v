module main

import math
import strconv

fn main_func() {
	a := 7
	b := 3
	c := 2
	println(py2v_integer_mul1(int(py2v_integer_add1(a, b, 'binop_parens.py:7', 'addition')), c, 'binop_parens.py:7', 'multiplication'))
	println(py2v_integer_sub1(a, py2v_integer_sub1(b, c, 'binop_parens.py:8', 'subtraction'), 'binop_parens.py:8', 'subtraction'))
	println(py2v_integer_sub1(a, int(py2v_integer_add1(b, c, 'binop_parens.py:9', 'addition')), 'binop_parens.py:9', 'subtraction'))
	println(py2v_integer_mul1(a, int(py2v_integer_mod1(b, c, 'binop_parens.py:10')), 'binop_parens.py:10', 'multiplication'))
	println(py2v_integer_mod1(int(py2v_integer_add1(a, b, 'binop_parens.py:11', 'addition')), int(py2v_integer_add1(int(py2v_integer_add1(b, c, 'binop_parens.py:11', 'addition')), 1, 'binop_parens.py:11', 'addition')), 'binop_parens.py:11'))
	println(py2v_integer_mul1(py2v_integer_neg1(py2v_integer_sub1(a, b, 'binop_parens.py:12', 'subtraction'), 'binop_parens.py:12'), c, 'binop_parens.py:12', 'multiplication'))
	println(~(py2v_integer_add1(a, b, 'binop_parens.py:13', 'addition')))
	println(py2v_integer_mul1(+(py2v_integer_sub1(b, a, 'binop_parens.py:14', 'subtraction')), c, 'binop_parens.py:14', 'multiplication'))
	println(py2v_integer_left_shift1(int(py2v_integer_add1(a, b, 'binop_parens.py:17', 'addition')), c, 'binop_parens.py:17'))
	println(py2v_integer_left_shift1(a, int(py2v_integer_add1(b, c, 'binop_parens.py:18', 'addition')), 'binop_parens.py:18'))
	println(b & py2v_integer_add1(a, c, 'binop_parens.py:19', 'addition'))
	println(a | (b ^ c))
	println(py2v_integer_add1(int(py2v_integer_mul1(a, b, 'binop_parens.py:23', 'multiplication')), c, 'binop_parens.py:23', 'addition'))
	println(py2v_integer_sub1(py2v_integer_sub1(a, b, 'binop_parens.py:24', 'subtraction'), c, 'binop_parens.py:24', 'subtraction'))
	println(a ^ b & c)
	x := 7.5
	y := 2.5
	z := 3.0
	println(py2v_float_text1(math.floor((x + y) / z)))
	s := 'ab'
	t := 'c'
	println((s + t).repeat(2))
	p := true
	q := false
	r := true
	if p && (q || r) {
		println('p and (q or r)')
	}
	if (p && q) || r {
		println('(p and q) or r')
	}
	if p != (a < b) {
		println('p xor (a < b)')
	}
	println((s + (t + s)).to_upper())
	if p != ((q && r) == q) {
		println('wrong')
	} else {
		println('p xor ((q and r) == q) is false')
	}
	if p && (q || r) {
		println('p and (q or r), again')
	}
	println(py2v_integer_neg1(py2v_integer_neg1(a, 'binop_parens.py:57'), 'binop_parens.py:57'))
	mut total := 0
	py2v_range_start1 := int(py2v_integer_sub1(c, py2v_integer_sub1(b, a, 'binop_parens.py:61', 'subtraction'), 'binop_parens.py:61', 'subtraction'))
	py2v_range_stop2 := int(py2v_integer_add1(a, 1, 'binop_parens.py:61', 'addition'))
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		total = py2v_integer_add1(total, i, 'binop_parens.py:62', 'addition')
	}
	println(total)
	mut w := 7.5
	w = math.floor(w / (y - (z - y)))
	println(py2v_float_text1(w))
	println(int((t + '').runes()[0]))
	pair := [1, 7]
	if pair.len == 2 && (pair[0] == 1 || pair[0] == 2) && pair[1] == 7 {
		println('pair matched')
	} else {
		println('pair missed')
	}
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
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
}

@[inline]
fn py2v_integer_mod1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer modulo by zero') }
	if b == -1 { return 0 }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return if adjust { r + b } else { r }
}

@[inline]
fn py2v_integer_neg1(value int, site string) int {
	if value == -9223372036854775807 - 1 { py2v_integer_overflow1(site, 'negation') }
	return -value
}

@[inline]
fn py2v_integer_left_shift1(a int, b int, site string) int {
	if b < 0 { panic('ValueError: negative shift count') }
	if a == 0 { return 0 }
	max := int(9223372036854775807)
	min := -max - 1
	if b == 63 && a == -1 { return min }
	if b >= 63 || a > (max >> b) || a < (min >> b) {
		py2v_integer_overflow1(site, 'left shift')
	}
	return a * (int(1) << b)
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
	main_func()
}
