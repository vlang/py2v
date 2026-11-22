module main

fn parse(line string) []int {
	return py2v_split_whitespace1(line).map((py2v_int_base1(it, 10, 'map_builtin_types.py:2') or { panic('ValueError: ' + err.msg()) })).clone()
}

fn halves(line string) []f64 {
	return line.split(',').map(it.f64()).clone()
}

fn texts(numbers []int) []string {
	return numbers.map(it.str()).clone()
}

fn whole(values []f64) []int {
	return values.map(py2v_integer_from_float1(f64(it), 'map_builtin_types.py:14')).clone()
}

fn pair(line string) int {
	py2v_unpack1 := py2v_split_whitespace1(line).map((py2v_int_base1(it, 10, 'map_builtin_types.py:18') or { panic('ValueError: ' + err.msg()) }))
	mut a := py2v_unpack1[0]
	mut b := py2v_unpack1[1]
	return py2v_integer_mul1(a, b, 'map_builtin_types.py:19', 'multiplication')
}

fn py2v_split_whitespace1(value string) []string {
	return value.split_any(' \t\n\r\u000b\u000c\u001c\u001d\u001e\u001f\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000').filter(it != '')
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
fn py2v_integer_from_float1(value f64, site string) int {
	if !(value >= -9223372036854775808.0 && value < 9223372036854775808.0) {
		py2v_integer_overflow1(site, 'float to integer conversion')
	}
	return int(value)
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
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
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

fn main() {
	println(parse('3 14 15'))
	println(py2v_integer_sum1(parse('1 2 3'), 0, 'map_builtin_types.py:23'))
	println(halves('1.5,2.25'))
	println(texts([1, 2, 3]))
	println(whole([1.9, 2.1]))
	println(pair('6 7'))
	println([4, 5].map(it.str()).join(' '))
	println(py2v_integer_sum1('1234'.split('').map((py2v_int_base1(it, 10, 'map_builtin_types.py:29') or { panic('ValueError: ' + err.msg()) })), 0, 'map_builtin_types.py:29'))
}
