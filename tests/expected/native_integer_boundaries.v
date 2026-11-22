module main

import math
import arrays
import strconv
import math.bits as py2v_math_bits1

fn number(text string) int {
	return py2v_int_base1(text, 10, 'native_integer_boundaries.py:5') or { panic('ValueError: ' + err.msg()) }
}

fn count_nonzero(values []int) int {
	mut count := 0
	for value in values {
		if value != 0 {
			count += 1
		}
	}
	return count
}

fn masked_accumulator(text string) int {
	mut state := 5381
	for character in text.split('') {
		state = py2v_integer_add1(int(py2v_integer_add1(int(py2v_integer_left_shift1(state, 5, 'native_integer_boundaries.py:19')), state, 'native_integer_boundaries.py:19', 'addition')), int(character.runes()[0]), 'native_integer_boundaries.py:19', 'addition') & i64(4294967295)
	}
	return state & i64(4294967295)
}

fn shift_last(mut values []int) int {
	println('rhs')
	values << 20
	return 5
}

fn last_index() int {
	println('index')
	return -1
}

fn main_func() {
	high := number('9_223_372_036_854_775_807')
	low := number('-9223372036854775808')
	println(number('٢١٤٧٤٨٣٦٤٨'))
	println(number('4294967296'))
	println(number('9007199254740991'))
	println(number('9007199254740992'))
	println(number('9007199254740993'))
	println(number('1099511627776'))
	println('${low} ${high} ${low + 1} ${high - 1}')
	println('${low - low} ${high + low} ${low * 1}')
	root := number('3037000499')
	println(py2v_integer_mul1(root, root, 'native_integer_boundaries.py:46', 'multiplication'))
	for count in [0, 1, 63, 64, 65, i64(4294967296)] {
		println((py2v_integer_right_shift1(low, count, 'native_integer_boundaries.py:48')).str() + ' ' + (py2v_integer_right_shift1(high, count, 'native_integer_boundaries.py:48')).str() + ' ' + (py2v_integer_left_shift1(0, count, 'native_integer_boundaries.py:48')).str())
	}
	println(py2v_integer_left_shift1(number('-1'), 63, 'native_integer_boundaries.py:49'))
	println((py2v_integer_mod1(low, -1, 'native_integer_boundaries.py:50')).str() + ' ' + (math.divide_floored[int](high, -3).quot).str() + ' ' + (2).str() + ' ' + (-2).str())
	py2v_unpack1 := py2v_integer_divmod1(low, high, 'native_integer_boundaries.py:51')
	mut quot := py2v_unpack1[0]
	mut rem := py2v_unpack1[1]
	println('${quot} ${rem}')
	println((py2v_integer_power1(high, 1, 'native_integer_boundaries.py:53')).str() + ' ' + (py2v_integer_power1(1, high, 'native_integer_boundaries.py:53')).str() + ' ' + (py2v_integer_power1(-1, high, 'native_integer_boundaries.py:53')).str() + ' ' + (py2v_integer_power1(0, high, 'native_integer_boundaries.py:53')).str())
	println((int(arrays.fold([-1, high], 1, |acc, item| acc + int(item)))).str() + ' ' + (py2v_integer_sum1([
		1,
		-1,
	], low, 'native_integer_boundaries.py:54')).str())
	println('${py2v_float_text1(py2v_sum_float_suffix1([f64(2.5)], f64(arrays.fold([int(1)], 0, |acc, item| acc + item))))} ${py2v_float_text1(py2v_sum_float_suffix1([f64(2.0)], f64(arrays.fold([int(1)], 0, |acc, item| acc + item))))}')
	println('${int(math.factoriali(0))} ${int(math.factoriali(20))}')
	println('${py2v_integer_isqrt1(high)} ${math.gcd[int](low, 6)} ${math.lcm[int](high, high)}')
	println('${int(-9.223372036854776e+18)} ${int(4.294967296e+09)} ${int(-4.9)}')
	py2v_enumerated2 := [3, 5]
	py2v_enum_start3 := high - 1
	for py2v_enum_index4, value in py2v_enumerated2 {
		index := py2v_enum_index4 + py2v_enum_start3
		println('${index} ${value}')
	}
	mut values := [7, 11]
	mut py2v_container5 := &values
	py2v_index6 := last_index()
	py2v_old7 := (*py2v_container5)[if py2v_index6 < 0 {
		py2v_container5.len + py2v_index6
	} else {
		py2v_index6
	}]
	py2v_aug_result8 := py2v_old7 + shift_last(mut values)
	(*py2v_container5)[if py2v_index6 < 0 { py2v_container5.len + py2v_index6 } else { py2v_index6 }] = py2v_aug_result8
	println(values)
	println(count_nonzero([-1, 0, 2, 3]))
	println((masked_accumulator('Algorithms')).str() + ' ' + (masked_accumulator('scramble bits')).str())
	println(masked_accumulator(''))
	py2v_range_stop9 := int(values.len)
	for position in int(0) .. py2v_range_stop9 {
		println(position + 1)
	}
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

fn py2v_int_base1(value string, requested_base int, site string) !int {
	if requested_base != 0 && (requested_base < 2 || requested_base > 36) {
		return error('int() base must be >= 2 and <= 36, or 0')
	}
	mut normalized := []u8{cap: value.len}
	for ch in value.runes() {
		if ch < 128 {
			normalized << u8(ch)
		} else if ch in [0x85, 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000] || (ch >= 0x2000 && ch <= 0x200a) {
			normalized << ` `
		} else {
			// Unicode decimal digit groups start at zero and contain ten runes.
			mut digit := u8(`?`)
			for zero in [0x660, 0x6f0, 0x7c0, 0x966, 0x9e6, 0xa66, 0xae6, 0xb66, 0xbe6, 0xc66,
				0xce6, 0xd66, 0xde6, 0xe50, 0xed0, 0xf20, 0x1040, 0x1090, 0x17e0, 0x1810, 0x1946,
				0x19d0, 0x1a80, 0x1a90, 0x1b50, 0x1bb0, 0x1c40, 0x1c50, 0xa620, 0xa8d0, 0xa900,
				0xa9d0, 0xa9f0, 0xaa50, 0xabf0, 0xff10, 0x104a0, 0x10d30, 0x10d40, 0x11066, 0x110f0,
				0x11136, 0x111d0, 0x112f0, 0x11450, 0x114d0, 0x11650, 0x116c0, 0x116d0, 0x116da,
				0x11730, 0x118e0, 0x11950, 0x11bf0, 0x11c50, 0x11d50, 0x11da0, 0x11de0, 0x11f50,
				0x16130, 0x16a60, 0x16ac0, 0x16b50, 0x16d70, 0x1ccf0, 0x1d7ce, 0x1d7d8, 0x1d7e2,
				0x1d7ec, 0x1d7f6, 0x1e140, 0x1e2f0, 0x1e4f0, 0x1e5f1, 0x1e950, 0x1fbf0]! {
				if int(ch) >= zero && int(ch) <= zero + 9 {
					digit = u8(int(ch) - zero) + `0`
					break
				}
			}
			normalized << digit
		}
	}
	text := normalized.bytestr().trim(' \t\n\r\u000b\u000c')
	if text == '' {
		return error('invalid literal for int()')
	}
	negative := text[0] == `-`
	mut start := if negative || text[0] == `+` { 1 } else { 0 }
	mut base := if requested_base == 0 { 10 } else { requested_base }
	mut zero_only := requested_base == 0 && start < text.len && text[start] == `0`
	if start < text.len - 1 && text[start] == `0` {
		prefix_base := match text[start + 1] | 32 {
			`b` { 2 }
			`o` { 8 }
			`x` { 16 }
			else { 0 }
		}
		if prefix_base != 0 && (requested_base == 0 || requested_base == prefix_base) {
			base = prefix_base
			zero_only = false
			start += 2
			if start < text.len && text[start] == `_` {
				start++
			}
		}
	}
	limit := (u64(1) << 63) - u64(!negative)
	mut magnitude := u64(0)
	mut overflow := false
	mut need_digit := true
	radix := u64(base)
	for i in start .. text.len {
		ch := text[i]
		if ch == `_` && !need_digit {
			need_digit = true
			continue
		}
		digit := match ch {
			`0`...`9` { int(ch - `0`) }
			`a`...`z` { int(ch - `a`) + 10 }
			`A`...`Z` { int(ch - `A`) + 10 }
			else { base }
		}
		if digit >= base || (zero_only && digit != 0) {
			return error('invalid literal for int()')
		}
		need_digit = false
		if !overflow {
			overflow = magnitude > (limit - u64(digit)) / radix
			if !overflow {
				magnitude = magnitude * radix + u64(digit)
			}
		}
	}
	if need_digit {
		return error('invalid literal for int()')
	}
	if overflow {
		py2v_integer_overflow1(site, 'integer parsing')
	}
	if magnitude == 0 {
		return 0
	}
	return if negative { -int(magnitude - 1) - 1 } else { int(magnitude) }
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
fn py2v_integer_right_shift1(a int, b int, _ string) int {
	if b < 0 { panic('ValueError: negative shift count') }
	if b >= 63 { return if a < 0 { -1 } else { 0 } }
	return a >> b
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
fn py2v_integer_floor_div1(a int, b int, _ string) int {
	if b == 0 { panic('ZeroDivisionError: integer division or modulo by zero') }
	r := a % b
	adjust := r != 0 && (r < 0) != (b < 0)
	return a / b - int(adjust)
}

fn py2v_integer_divmod1(a int, b int, site string) []int {
	return [py2v_integer_floor_div1(a, b, site), py2v_integer_mod1(a, b, site)]
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

fn py2v_integer_sum1[T](items []T, start int, site string) int {
	$if (T is $int && T !is u64) || T is bool {
		mut total := start
		for item in items { total = py2v_integer_add1(total, int(item), site, 'sum') }
		return total
	} $else {
		$compile_error('py2v_unsupported_integer_sum: expected native integer elements')
	}
}

fn py2v_sum_float_suffix1(items []f64, start f64) f64 {
	mut total := start
	for item in items { total += item }
	return total
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

fn py2v_integer_isqrt1(value int) int {
	if value < 0 { panic('ValueError: isqrt() argument must be nonnegative') }
	mut remainder := u64(value)
	mut root := u64(0)
	mut bit := u64(1) << 62
	for bit > remainder { bit >>= 2 }
	for bit != 0 {
		trial := root + bit
		root >>= 1
		if remainder >= trial {
			remainder -= trial
			root += bit
		}
		bit >>= 2
	}
	return int(root)
}

@[inline]
fn py2v_integer_word_product1(a u64, b u64, modulus u64) u64 {
	hi, lo := py2v_math_bits1.mul_64(a, b)
	return py2v_math_bits1.rem_64(hi, lo, modulus)
}

fn py2v_modular_pow1(base int, exponent int, modulus int) !int {
	if modulus == 0 {
		return error('pow() 3rd argument cannot be 0')
	}
	if modulus == 1 || modulus == -1 {
		return 0
	}
	m := if modulus < 0 { u64(-(modulus + 1)) + 1 } else { u64(modulus) }
	remainder := base % modulus
	mut x := if remainder < 0 { m - u64(-remainder) } else { u64(remainder) }
	if exponent < 0 {
		// Euclid's coefficients can be kept reduced modulo m throughout.
		mut old_r, mut r := m, x
		mut old_coefficient, mut coefficient := u64(0), u64(1)
		for r != 0 {
			product := py2v_integer_word_product1(old_r / r, coefficient, m)
			old_r, r = r, old_r % r
			old_coefficient, coefficient = coefficient, if old_coefficient >= product {
				old_coefficient - product
			} else {
				m - (product - old_coefficient)
			}
		}
		if old_r != 1 {
			return error('base is not invertible for the given modulus')
		}
		x = old_coefficient
	}
	mut degree := if exponent < 0 { u64(-(exponent + 1)) + 1 } else { u64(exponent) }
	mut result := u64(1)
	for degree != 0 {
		if degree & 1 != 0 {
			result = py2v_integer_word_product1(result, x, m)
		}
		degree >>= 1
		if degree != 0 {
			x = py2v_integer_word_product1(x, x, m)
		}
	}
	return if modulus < 0 && result != 0 { -int(m - result) } else { int(result) }
}

fn main() {
	main_func()
	high := number('9223372036854775807')
	low := number('-9223372036854775808')
	println((py2v_modular_pow1(int(high), int(high), int(low)) or { panic('ValueError: ' + err.msg()) }).str() + ' ' + (py2v_modular_pow1(int(2), int(-1), int(-17)) or { panic('ValueError: ' + err.msg()) }).str() + ' ' + (py2v_modular_pow1(int(3), int(low), int(17)) or { panic('ValueError: ' + err.msg()) }).str())
	println((py2v_modular_pow1(int(5), int(0), int(-1)) or { panic('ValueError: ' + err.msg()) }).str() + ' ' + (py2v_modular_pow1(int(99), int(0), int(-17)) or { panic('ValueError: ' + err.msg()) }).str())
}
