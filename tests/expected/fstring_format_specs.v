module main

import math
import math.big as py2v_big

fn show(price f64, count int, name string) string {
	return '${py2v_format(name, '', '<', '', false, 8, '', -1, '')}|${py2v_format(count, '', '>', '', false, 5, '', -1, '')}|${py2v_format(price, '', '>', '', false, 10, ',', 2, 'f')}'
}

// py2v_format formats x as Python's format(x, spec) does, from the spec fields
// py2v parsed: fill, align ('' for the default), sign, the 0 flag, width,
// grouping separator, precision (-1 when absent) and type.
fn py2v_format[T](x T, fill string, align string, sign string, zero bool, width int, group string, prec int, typ string) string {
	mut body := ''
	mut numeric := true
	$if T is rune {
		numeric = false
		body = if prec == 0 { '' } else { x.str() }
	} $else $if T is $int {
		if typ in ['e', 'E', 'f', 'F', 'g', 'G', '%'] {
			body = py2v_format_float(f64(x), sign, prec, typ)
		} else {
			mut neg := false
			mut mag := u64(0)
			$if T is u64 {
				mag = x
			} $else {
				v := i64(x)
				neg = v < 0
				mag = if neg { u64(-(v + 1)) + 1 } else { u64(v) }
			}
			body = if neg {
				'-'
			} else if sign == '-' {
				''
			} else {
				sign
			}
			body += mag.str()
		}
	} $else $if T is $float {
		if typ !in ['e', 'E', 'f', 'F', 'g', 'G', '%'] {
			return '${x}'
		}
		body = py2v_format_float(f64(x), sign, prec, typ)
	} $else $if T is string {
		numeric = false
		body = if prec >= 0 { x.runes()#[..prec].string() } else { x }
	} $else {
		return '${x}'
	}
	if group != '' {
		i := if body[0] in [`+`, `-`, ` `] { 1 } else { 0 }
		mut j := i
		for j < body.len && body[j].is_digit() {
			j++
		}
		mut digits := body[i..j]
		mut grouped := ''
		for digits.len > 3 {
			grouped = group + digits[digits.len - 3..] + grouped
			digits = digits[..digits.len - 3]
		}
		body = body[..i] + digits + grouped + body[j..]
	}
	pad := width - body.runes().len
	a := if align != '' {
		align
	} else if !numeric {
		'<'
	} else if zero {
		'='
	} else {
		'>'
	}
	f := if fill != '' {
		fill
	} else if zero {
		'0'
	} else {
		' '
	}
	return match a {
		'<' { body + f.repeat(pad) }
		'^' { f.repeat(pad / 2) + body + f.repeat(pad - pad / 2) }
		'=' {
			s := if body[0] in [`+`, `-`, ` `] { body[..1] } else { '' }
			s + f.repeat(pad) + body[s.len..]
		}
		else { f.repeat(pad) + body }
	}
}

// Round the exact binary64 decimal expansion to the requested number of places.
fn py2v_format_float(x f64, sign string, prec int, typ string) string {
	value := if typ == '%' { x * 100.0 } else { x }
	bits := math.f64_bits(value)
	biased := int((bits >> 52) & 0x7ff)
	fraction := bits & 0x000f_ffff_ffff_ffff
	negative := bits >> 63 != 0 && !(biased == 0x7ff && fraction != 0)
	prefix := if negative {
		'-'
	} else if sign != '-' {
		sign
	} else {
		''
	}
	suffix := if typ == '%' { '%' } else { '' }
	upper := typ in ['E', 'F', 'G']
	if biased == 0x7ff {
		word := if fraction == 0 { 'inf' } else { 'nan' }
		return prefix + (if upper { word.to_upper() } else { word }) + suffix
	}
	mut digits := '0'
	mut scale := 0
	if value != 0.0 {
		mantissa := py2v_big.integer_from_u64(if biased == 0 {
			fraction
		} else {
			fraction | (u64(1) << 52)
		})
		unit := if biased == 0 { -1074 } else { biased - 1075 }
		if unit >= 0 {
			digits = mantissa.left_shift(u32(unit)).str()
		} else {
			scale = -unit
			digits = (mantissa * py2v_big.integer_from_int(5).pow(u32(scale))).str()
		}
	}
	p := if prec >= 0 { prec } else { 6 }
	if typ in ['f', 'F', '%'] {
		fixed := py2v_format_round(digits, digits.len - scale + p)
		return prefix + py2v_format_point(fixed, fixed.len - p) + suffix
	}
	general := typ in ['g', 'G']
	significant := if general && p == 0 {
		1
	} else if general {
		p
	} else {
		p + 1
	}
	mut exponent := digits.len - scale - 1
	mut rounded := py2v_format_round(digits, significant)
	if rounded.len > significant {
		exponent++
		rounded = rounded[..significant]
	}
	if general && exponent >= -4 && exponent < significant {
		return prefix + py2v_format_trim(py2v_format_point(rounded, exponent + 1))
	}
	mantissa := py2v_format_point(rounded, 1)
	marker := if upper { 'E' } else { 'e' }
	exp_sign := if exponent < 0 { '-' } else { '+' }
	exp_digits := (if exponent < 0 { -exponent } else { exponent }).str()
	return prefix + (if general { py2v_format_trim(mantissa) } else { mantissa }) +
		marker + exp_sign + '0'.repeat(2 - exp_digits.len) + exp_digits
}

fn py2v_format_round(digits string, keep int) string {
	if keep >= digits.len {
		return digits + '0'.repeat(keep - digits.len)
	}
	if keep < 0 {
		return '0'
	}
	kept := if keep == 0 { '0' } else { digits[..keep] }
	next := digits[keep]
	odd := (kept[kept.len - 1] - 48) % 2 != 0
	if next > 53 || (next == 53 && (odd || digits[keep + 1..].trim_left('0') != '')) {
		integer := py2v_big.integer_from_string(kept) or { panic(err) }
		return (integer + py2v_big.integer_from_int(1)).str()
	}
	return kept
}

fn py2v_format_point(digits string, point int) string {
	if point <= 0 {
		return '0.' + '0'.repeat(-point) + digits
	}
	if point >= digits.len {
		return digits + '0'.repeat(point - digits.len)
	}
	return digits[..point] + '.' + digits[point..]
}

fn py2v_format_trim(value string) string {
	return if value.contains('.') { value.trim_right('0').trim_right('.') } else { value }
}

fn main() {
	tie := 0.125
	half := 2.5
	big := 1e+22
	small := -0.001
	ratio := 0.4567
	n := 1234567
	neg := -42
	word := 'héllo'
	println('${py2v_format(tie, '', '', '', false, 0, '', 2, 'f')} ${py2v_format(half, '', '', '', false, 0, '', 0, 'f')} ${py2v_format(big, '', '', '', false, 0, '', 2, 'f')} ${py2v_format(small, '', '', '', false, 0, '', 1, 'f')}')
	println('${py2v_format(ratio, '', '', '', false, 0, '', 1, '%')} ${py2v_format(ratio, '', '', '+', false, 0, '', 0, '%')} ${py2v_format(n, '', '', '', false, 0, '', -1, 'g')} ${py2v_format(ratio, '', '', '', false, 0, '', 3, 'e')} ${py2v_format(n, '', '', '', false, 0, ',', 0, 'f')}')
	println('[${py2v_format(half, '', '', '+', true, 8, '', 2, 'f')}] [${py2v_format(half, '*', '^', '', false, 9, '', 1, 'f')}] [${py2v_format(half, '', '<', '', false, 7, '', 1, 'f')}] [${py2v_format(half, '', '=', '+', false, 9, '', 1, 'f')}]')
	println('${py2v_format(n, '', '', '', false, 0, ',', -1, '')} ${py2v_format(n, '', '', '+', false, 0, ',', -1, '')} ${py2v_format(n, '', '', '', false, 0, '_', -1, '')} ${py2v_format(neg, '', '', '', true, 5, '', -1, 'd')} ${py2v_format(neg, '', '>', '', false, 6, '', -1, '')} ${py2v_format(7, '', '', '', true, 3, '', -1, 'd')} ${py2v_format(neg, '', '', '+', false, 0, '', -1, 'd')}')
	println('[${py2v_format(word, '', '>', '', false, 8, '', -1, '')}] [${py2v_format(word, '', '^', '', false, 9, '', -1, '')}] [${py2v_format(word, '*', '<', '', false, 7, '', -1, '')}] [${py2v_format(word, '', '', '', false, 0, '', 3, 's')}]')
	println(show(1234.5, 3, 'apples'))
}
