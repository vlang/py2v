module main

import math
import strconv

fn main_func() {
	a := 7
	b := 3
	c := 2
	println((a + b) * c)
	println(a - (b - c))
	println(a - (b + c))
	println(a * math.modulo_floored(b, c))
	println(math.modulo_floored(a + b, b + c + 1))
	println(-(a - b) * c)
	println(~(a + b))
	println(+(b - a) * c)
	println((a + b) << c)
	println(a << (b + c))
	println(b & (a + c))
	println(a | (b ^ c))
	println(a * b + c)
	println(a - b - c)
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
	println(-(-a))
	mut total := 0
	py2v_range_start1 := int(c - (b - a))
	py2v_range_stop2 := int(a + 1)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for i := py2v_range_start1; if py2v_range_step3 > 0 {
		i < py2v_range_stop2
	} else {
		i > py2v_range_stop2
	}; i = py2v_range_next1(i, py2v_range_stop2, py2v_range_step3) {
		total += i
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
