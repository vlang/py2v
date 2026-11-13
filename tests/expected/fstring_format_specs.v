module main

fn show(price f64, count int, name string) string {
	return '${py2v_format(name, '', '<', '', false, 8, '', -1, '')}|${py2v_format(count, '', '>', '', false, 5, '', -1, '')}|${py2v_format(price, '', '>', '', false, 10, ',', 2, 'f')}'
}

// py2v_format formats x as Python's format(x, spec) does, from the spec fields
// py2v parsed: fill, align ('' for the default), sign, the 0 flag, width,
// grouping separator, precision (-1 when absent) and type. Floats go through
// C's snprintf, which rounds the exact binary value as CPython does. A value
// or spec not covered here prints as plain interpolation would.
fn py2v_format[T](x T, fill string, align string, sign string, zero bool, width int, group string, prec int, typ string) string {
	mut body := ''
	mut numeric := true
	$if T is rune {
		numeric = false
		body = if prec == 0 { '' } else { x.str() }
	} $else $if T is $int {
		if typ in ['e', 'E', 'f', 'F', 'g', 'G', '%'] {
			body = py2v_format_c(f64(x), sign, prec, typ)
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
		body = py2v_format_c(f64(x), sign, prec, typ)
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

// py2v_format_c formats x for Python's types e, E, f, F, g, G and %.
fn py2v_format_c(x f64, sign string, prec int, typ string) string {
	if x != x {
		// C libraries differ on the sign of a NaN; Python prints none unless the spec asks.
		nan := if typ in ['E', 'F', 'G'] { 'NAN' } else { 'nan' }
		return (if sign == '-' { '' } else { sign }) + nan + if typ == '%' { '%' } else { '' }
	}
	p := if prec >= 0 { prec } else { 6 }
	cfmt := if typ == '%' { '%${sign}.${p}f%%' } else { '%${sign}.${p}${typ}' }
	v := if typ == '%' { x * 100.0 } else { x }
	n := unsafe { C.snprintf(nil, 0, &char(cfmt.str), v) }
	mut buf := []u8{len: n + 1}
	unsafe { C.snprintf(&char(buf.data), uint(n + 1), &char(cfmt.str), v) }
	return buf[..n].bytestr()
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
