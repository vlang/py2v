module main

import strconv

fn presentation(value int) string {
	return '${py2v_format_radix1(value, '', '', '', true, 8, '', -1, 'b')} ${py2v_format_radix1(value, '', '', '+', true, 10, '', -1, '#x')} ${py2v_format_radix1(value, '*', '>', '+', false, 10, '', -1, '#o')} ${py2v_format_radix1(value, '', '^', '', false, 12, '', -1, 'X')}'
}

fn py2v_format_radix1[T](value T, fill string, align string, sign string, zero bool, width int, group string, _ int, typ string) string {
	kind := typ[typ.len - 1]
	base := match kind {
		`b` { 2 }
		`o` { 8 }
		else { 16 }
	}
	mut negative := false
	mut magnitude := u64(0)
	$if T is u64 {
		magnitude = value
	} $else {
		x := i64(value)
		negative = x < 0
		magnitude = if negative { u64(-(x + 1)) + 1 } else { u64(x) }
	}
	mut prefix := if negative {
		'-'
	} else if sign == '-' {
		''
	} else {
		sign
	}
	if typ.len == 2 {
		prefix += '0' + kind.ascii_str()
	}
	mut digits := strconv.format_uint(magnitude, base)
	if kind == `X` {
		digits = digits.to_upper()
	}
	a := if align != '' {
		align
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
	if group == '_' {
		if a == '=' && f == '0' {
			mut length := digits.len
			for prefix.len + length + (length - 1) / 4 < width { length++ }
			digits = '0'.repeat(length - digits.len) + digits
		}
		mut parts := []string{}
		mut begin := (digits.len - 1) % 4 + 1
		parts << digits[..begin]
		for begin < digits.len {
			parts << digits[begin..begin + 4]
			begin += 4
		}
		digits = parts.join('_')
	}
	pad := width - prefix.len - digits.len
	if pad <= 0 {
		return prefix + digits
	}
	return match a {
		'<' { prefix + digits + f.repeat(pad) }
		'^' { f.repeat(pad / 2) + prefix + digits + f.repeat(pad - pad / 2) }
		'=' { prefix + f.repeat(pad) + digits }
		else { f.repeat(pad) + prefix + digits }
	}
}

fn py2v_bin1(n i64) string {
	if n < 0 {
		return '-0b' + strconv.format_uint(u64(-(n + 1)) + 1, 2)
	}
	return '0b' + strconv.format_int(n, 2)
}

fn main() {
	values := [0, 7, -42, 999999]
	for n in values {
		println(presentation(n))
		println(py2v_format_radix1(n, '', '', '', true, 18, '_', -1, '#b'))
		println('[${py2v_format_radix1(n, '*', '>', '', false, 12, '_', -1, 'b')}][${py2v_format_radix1(n, '', '', '', false, 0, '_', -1, '#X')}][${py2v_format_radix1(n, 'é', '^', '', false, 15, '', -1, 'o')}][${py2v_bin1(i64(n))}]')
	}
	println('${py2v_format_radix1(int(true), '', '', '', true, 8, '', -1, '#b')}')
	println('${py2v_format_radix1(u64(9223372036854775808), '', '', '', true, 18, '', -1, '#X')}')
}
