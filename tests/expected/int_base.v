module main

import strconv
import pyrt

type Py2vErrorArg = bool | i64 | string

fn (arg Py2vErrorArg) str() string {
	return match arg {
		bool {
			if arg { 'True' } else { 'False' }
		}
		i64 { arg.str() }
		string { arg }
	}
}

struct Py2vErrorArgs {
	values []Py2vErrorArg
}

fn (args Py2vErrorArgs) str() string {
	mut parts := []string{cap: args.values.len}
	for value in args.values {
		if value is string {
			quote := if value.contains('\x27') && !value.contains('\x22') { '\x22' } else { '\x27' }
			escaped := value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t').replace(quote, '\\' + quote)
			parts << quote + escaped + quote
		} else {
			parts << value.str()
		}
	}
	suffix := if parts.len == 1 { ',)' } else { ')' }
	return '(' + parts.join(', ') + suffix
}

struct Py2vErrorData {
	args     Py2vErrorArgs
	original ?IError
	cause    ?IError
}

fn (data Py2vErrorData) str() string {
	if data.args.values.len > 1 {
		return data.args.str()
	}
	value := data.args.values[0] or { return '' }
	return value.str()
}

struct Py2vErrorValueError {
	Error
	data Py2vErrorData
}

fn (err Py2vErrorValueError) msg() string {
	return err.data.str()
}

@[noreturn]
fn py2v_uncaught_exception1(err IError) {
	class_name := match err {
		Py2vErrorValueError { 'ValueError' }
		else { panic(err) }
	}
	message := err.msg()
	eprintln(if message == '' { class_name } else { class_name + ': ' + message })
	exit(1)
}

fn parse_digits_py(values []string, index int, base int) !int {
	text := values[index]
	return py2v_int_base1(text, int(base)) or { return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } }) }
}

fn py2v_int_base1(value string, requested_base int) !int {
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
	text := normalized.bytestr().trim_space()
	if text == '' {
		return error('invalid literal for int() with base ${requested_base}: ' + pyrt.repr(pyrt.box(value)))
	}
	negative := text[0] == `-`
	mut start := if negative || text[0] == `+` { 1 } else { 0 }
	mut base := if requested_base == 0 { 10 } else { requested_base }
	mut zero_only := requested_base == 0 && start < text.len && text[start] == `0`
	if start + 1 < text.len && text[start] == `0` {
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
	magnitude, status := strconv.common_parse_uint2(text[start..], base, 64)
	limit := (u64(1) << (sizeof(int) * 8 - 1)) - u64(!negative)
	if status == -3 || (status == 0 && magnitude > limit) {
		panic('py2v_unsupported_int_range: based integer is outside native int')
	}
	if status != 0 || (zero_only && magnitude != 0) {
		return error('invalid literal for int() with base ${requested_base}: ' + pyrt.repr(pyrt.box(value)))
	}
	if magnitude == 0 {
		return 0
	}
	return if negative { -int(magnitude - 1) - 1 } else { int(magnitude) }
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

fn py2v_entry1() ! {
	values := [' -0x_Ff　', '0o_17', '٠b_١٠١', '00_0', '+1_0', 'Z', '-8000_0000_0000_0000']
	bases := [0, 8, 0, 0, 2, 36, 16]
	py2v_range_start1 := int(0)
	py2v_range_stop2 := int(values.len)
	py2v_range_step3 := int(1)
	if py2v_range_step3 == 0 { panic('ValueError: range() arg 3 must not be zero') }
	for index := py2v_range_start1; if py2v_range_step3 > 0 {
		index < py2v_range_stop2
	} else {
		index > py2v_range_stop2
	}; index = py2v_range_next1(index, py2v_range_stop2, py2v_range_step3) {
		println(parse_digits_py(values, index, bases[index])!)
	}
	println((py2v_int_base1('0b1', int(16)) or { return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } }) }))
	println((py2v_int_base1('00', int(10)) or { return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } }) }))
	println((py2v_int_base1('1', int(int(true) + 1)) or { return IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } }) }))
	for invalid in ['01', '', '_0', '0x__f', '0b', '0o9', '0_xa', '10\x00', '3\x1c', '²'] {
		mut py2v_err_2 := ?IError(none)
		py2v_try_2: for {
			println((py2v_int_base1(invalid, int(0)) or {
				py2v_err_2 = IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } })
				break py2v_try_2
			}))
			break
		}
		if py2v_raised_2 := py2v_err_2 {
			if py2v_raised_2 is Py2vErrorValueError {
				println('invalid')
			} else {
				return py2v_raised_2
			}
		}
	}
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		println((py2v_int_base1('40', int(37)) or {
			py2v_err_1 = IError(Py2vErrorValueError{ data: Py2vErrorData{ args: Py2vErrorArgs{ values: [Py2vErrorArg(err.msg())] } } })
			break py2v_try_1
		}))
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if py2v_raised_1 is Py2vErrorValueError {
			println('invalid base')
		} else {
			return py2v_raised_1
		}
	}
}

fn main() {
	py2v_entry1() or { py2v_uncaught_exception1(err) }
}
