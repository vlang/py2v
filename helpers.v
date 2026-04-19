module main

import strings
import math

// indent indents each non-empty line of `code` by `level` using `indent_str`.
pub fn indent(code string, level int, indent_str string) string {
	if code == '' {
		return code
	}
	prefix := indent_str.repeat(level)
	lines := code.split('\n')
	mut result := []string{}
	for line in lines {
		if line.len > 0 {
			result << prefix + line
		} else {
			result << ''
		}
	}
	return result.join('\n')
}

// join_non_empty joins non-empty `items` with `sep`.
pub fn join_non_empty(items []string, sep string) string {
	mut filtered := []string{}
	for item in items {
		if item.len > 0 {
			filtered << item
		}
	}
	return filtered.join(sep)
}

// StringBuilder for efficient string concatenation
pub struct StringBuilder {
mut:
	buf strings.Builder
}

// new_string_builder returns a pre-sized StringBuilder.
pub fn new_string_builder() StringBuilder {
	return StringBuilder{
		buf: strings.new_builder(1024)
	}
}

// write appends `s` to the builder.
pub fn (mut sb StringBuilder) write(s string) {
	sb.buf.write_string(s)
}

// writeln appends `s` and a newline to the builder.
pub fn (mut sb StringBuilder) writeln(s string) {
	sb.buf.write_string(s)
	sb.buf.write_string('\n')
}

// str returns the built string.
pub fn (mut sb StringBuilder) str() string {
	return sb.buf.str()
}

// is_numeric_string returns true if `s` represents an integer or float literal.
pub fn is_numeric_string(s string) bool {
	if s == '' {
		return false
	}
	for i, c in s {
		if c == `-` && i == 0 {
			continue
		}
		if c == `.` {
			continue
		}
		if c < `0` || c > `9` {
			return false
		}
	}
	return true
}

// escape_string escapes characters in `s` for inclusion in a V string literal.
pub fn escape_string(s string) string {
	mut result := strings.new_builder(s.len)
	for c in s {
		match c {
			`\\` { result.write_string('\\\\') }
			`"` { result.write_string('\\"') }
			`'` { result.write_string("\\'") }
			`\n` { result.write_string('\\n') }
			`\r` { result.write_string('\\r') }
			`\t` { result.write_string('\\t') }
			else { result.write_u8(c) }
		}
	}
	return result.str()
}

// escape_interp_string escapes `s` for embedding inside a V single-quoted
// interpolated string literal. Same as escape_string but also escapes `$`
// when it is immediately followed by `{`, so that literal braced text in
// the original Python string is not mistaken for a V interpolation.
pub fn escape_interp_string(s string) string {
	mut result := strings.new_builder(s.len)
	for i, c in s {
		match c {
			`\\` {
				result.write_string('\\\\')
			}
			`'` {
				result.write_string("\\'")
			}
			`\n` {
				result.write_string('\\n')
			}
			`\r` {
				result.write_string('\\r')
			}
			`\t` {
				result.write_string('\\t')
			}
			`$` {
				// Escape $ only when followed by `{` to avoid accidental V interpolation.
				if i + 1 < s.len && s[i + 1] == `{` {
					result.write_string('\\$')
				} else {
					result.write_u8(c)
				}
			}
			else {
				result.write_u8(c)
			}
		}
	}
	return result.str()
}

// bytes_to_v_literal converts `data` to a V byte array literal string.
pub fn bytes_to_v_literal(data []u8) string {
	if data.len == 0 {
		return '[]u8{}'
	}
	mut parts := []string{}
	for i, b in data {
		if i == 0 {
			parts << 'byte(0x${b:02x})'
		} else {
			parts << '0x${b:02x}'
		}
	}
	return '[${parts.join(', ')}]'
}

// is_simple_expr returns true if `expr_type` is a simple expression that doesn't need parentheses.
pub fn is_simple_expr(expr_type string) bool {
	return expr_type in ['Constant', 'Name', 'Attribute', 'Subscript', 'Call', 'List', 'Dict',
		'Tuple']
}

// TmpVarGen generates unique temporary variable names.
pub struct TmpVarGen {
mut:
	counter int
}

// new_tmp_var_gen creates a new TmpVarGen with counter initialized.
pub fn new_tmp_var_gen() TmpVarGen {
	return TmpVarGen{
		counter: 0
	}
}

// next returns a fresh temporary name with `prefix`.
pub fn (mut g TmpVarGen) next(prefix string) string {
	g.counter++
	return '__${prefix}${g.counter}'
}

// is_numeric_type returns true if `typ` is a known numeric type.
pub fn is_numeric_type(typ string) bool {
	return typ in v_width_rank
}

// normalize_code strips trailing spaces/tabs from each line in `code`.
pub fn normalize_code(code string) string {
	lines := code.split('\n')
	mut result := []string{}
	for line in lines {
		trimmed := line.trim_right(' \t')
		result << trimmed
	}
	return result.join('\n')
}

// maybe_paren wraps `code` in parentheses if `needs_paren`.
pub fn maybe_paren(code string, needs_paren bool) string {
	if needs_paren {
		return '(${code})'
	}
	return code
}

// fmt_group_int formats integer `n` with thousands separators and optional width/zero-pad.
pub fn fmt_group_int(n i64, width int, zero_pad bool) string {
	s := n.str()
	mut neg := false
	mut digits := s
	if s.len > 0 && s[0] == `-` {
		neg = true
		digits = s[1..]
	}
	// Insert commas every 3 digits from the right
	mut parts := []string{}
	mut i := digits.len
	for i > 0 {
		start := if i - 3 > 0 { i - 3 } else { 0 }
		parts << digits[start..i]
		i = start
	}
	parts.reverse_in_place()
	mut out := parts.join(',')
	if neg {
		out = '-' + out
	}
	if width > out.len {
		pad_len := width - out.len
		padch := if zero_pad { '0' } else { ' ' }
		out = padch.repeat(pad_len) + out
	}
	return out
}

// fmt_center centers `s` in a field of given `width` using space fill.
pub fn fmt_center(s string, width int) string {
	if width <= s.len {
		return s
	}
	total := width - s.len
	left := total / 2
	right := total - left
	return ' '.repeat(left) + s + ' '.repeat(right)
}

// fmt_group_float formats float `f` with thousands separators in integer part,
// with given precision, width and zero_pad flags. `typ` accepts 'f','F','e','E','g','G'.
pub fn fmt_group_float(f f64, width int, zero_pad bool, precision int, typ string, sign_char string) string {
	mut val := f
	// Handle NaN/Inf conservatively
	if math.is_nan(val) {
		return 'nan'
	}
	if math.is_inf(val, 0) {
		if val < 0 {
			return '-inf'
		} else {
			return 'inf'
		}
	}

	mut neg := false
	if val < 0 {
		neg = true
		val = -val
	}

	// Determine formatting behavior based on type
	mut p := precision
	if p < 0 {
		p = 6
	}

	mut out := ''
	t := if typ != '' { typ[0] } else { `f` }

	if t == `f` || t == `F` {
		// Fixed-point formatting with grouping
		pow10 := math.pow(10, p)
		mut rounded := math.round(val * pow10)
		rounded_int := i64(rounded)
		pow10_i := i64(pow10)
		mut int_part := rounded_int / pow10_i
		mut frac_part := rounded_int % pow10_i
		// If rounding carried over
		if frac_part == pow10_i {
			int_part++
			frac_part = 0
		}
		mut int_grouped := fmt_group_int(int_part, 0, false)
		mut frac_str := ''
		if p > 0 {
			frac_str = frac_part.str()
			if frac_str.len < p {
				frac_str = '0'.repeat(p - frac_str.len) + frac_str
			}
			frac_str = '.' + frac_str
		}
		out = int_grouped + frac_str
		if neg {
			out = '-' + out
		}
	} else if t == `e` || t == `E` {
		// Scientific notation: one digit before decimal, p digits after decimal
		if val == 0.0 {
			mant := '0'
			frac := if p > 0 { '.' + '0'.repeat(p) } else { '' }
			exp_str := 'e+00'
			out = mant + frac + exp_str
			if neg {
				out = '-' + out
			}
		} else {
			exp := int(math.floor(math.log10(val)))
			mantissa := val / math.pow(10, exp)
			factor := math.pow(10, p)
			mut mant_rounded := math.round(mantissa * factor) / factor
			mut adj_exp := exp
			if mant_rounded >= 10.0 {
				mant_rounded /= 10.0
				adj_exp++
			}
			// build mantissa string
			int_part := i64(mant_rounded)
			mut frac_part_f := mant_rounded - f64(int_part)
			mut frac_str := ''
			if p > 0 {
				mut frac_val := math.round(frac_part_f * factor)
				frac_s := i64(frac_val).str()
				frac_str = '.' + ('0'.repeat(p - frac_s.len) + frac_s)
			}
			// exponent string
			mut sign_e := '+'
			if adj_exp < 0 {
				sign_e = '-'
			}
			mut ee := adj_exp
			if ee < 0 {
				ee = -ee
			}
			exp_num := if ee < 10 { '0' + ee.str() } else { ee.str() }
			e_char := if t == `E` { 'E' } else { 'e' }
			out = int_part.str() + frac_str + e_char + sign_e + exp_num
			if neg {
				out = '-' + out
			}
		}
	} else if t == `g` || t == `G` {
		// General format: significant digits = p
		if val == 0.0 {
			mut s := '0'
			if p > 1 {
				s += '.' + '0'.repeat(p - 1)
			}
			if t == `G` {
				s = s.to_upper()
			}
			out = s
			if neg {
				out = '-' + out
			}
		} else {
			exp := int(math.floor(math.log10(val)))
			// decide between fixed and scientific
			if exp < -4 || exp >= p {
				// scientific with p-1 digits after decimal
				mut pp := if p > 0 { p - 1 } else { 0 }
				mantissa := val / math.pow(10, exp)
				factor := math.pow(10, pp)
				mut mant_rounded := math.round(mantissa * factor) / factor
				mut adj_exp := exp
				if mant_rounded >= 10.0 {
					mant_rounded /= 10.0
					adj_exp++
				}
				int_part := i64(mant_rounded)
				mut frac_part_f := mant_rounded - f64(int_part)
				mut frac_s := ''
				if pp > 0 {
					mut frac_val := math.round(frac_part_f * factor)
					frac_s = i64(frac_val).str()
					frac_s = '.' + ('0'.repeat(pp - frac_s.len) + frac_s)
				}
				mut sign_e := '+'
				if adj_exp < 0 {
					sign_e = '-'
				}
				mut ee := adj_exp
				if ee < 0 {
					ee = -ee
				}
				exp_num := if ee < 10 { '0' + ee.str() } else { ee.str() }
				e_char := if t == `G` { 'E' } else { 'e' }
				out = int_part.str() + frac_s + e_char + sign_e + exp_num
				if neg {
					out = '-' + out
				}
			} else {
				// fixed format with p significant digits: digits after decimal = p - (exp+1)
				mut digits_after := p - (exp + 1)
				if digits_after < 0 {
					digits_after = 0
				}
				pow10 := math.pow(10, digits_after)
				mut rounded := math.round(val * pow10)
				rounded_int := i64(rounded)
				pow10_i := i64(pow10)
				mut int_part := rounded_int / pow10_i
				mut frac_part := rounded_int % pow10_i
				if frac_part == pow10_i {
					int_part++
					frac_part = 0
				}
				mut int_grouped := fmt_group_int(int_part, 0, false)
				mut frac_str := ''
				if digits_after > 0 {
					frac_str = frac_part.str()
					if frac_str.len < digits_after {
						frac_str = '0'.repeat(digits_after - frac_str.len) + frac_str
					}
					// strip trailing zeros
					mut trimmed := frac_str
					for trimmed.len > 0 && trimmed[trimmed.len - 1] == `0` {
						trimmed = trimmed[0..trimmed.len - 1]
					}
					if trimmed.len > 0 {
						frac_str = '.' + trimmed
					} else {
						frac_str = ''
					}
				}
				out = int_grouped + frac_str
				if neg {
					out = '-' + out
				}
			}
		}
	} else {
		// fallback to fixed
		pow10 := math.pow(10, p)
		mut rounded := math.round(val * pow10)
		rounded_int := i64(rounded)
		pow10_i := i64(pow10)
		mut int_part := rounded_int / pow10_i
		mut frac_part := rounded_int % pow10_i
		if frac_part == pow10_i {
			int_part++
			frac_part = 0
		}
		mut int_grouped := fmt_group_int(int_part, 0, false)
		mut frac_str := ''
		if p > 0 {
			frac_str = frac_part.str()
			if frac_str.len < p {
				frac_str = '0'.repeat(p - frac_str.len) + frac_str
			}
			frac_str = '.' + frac_str
		}
		out = int_grouped + frac_str
		if neg {
			out = '-' + out
		}
	}

	// Compose sign prefix if not already present
	mut sign_pref := ''
	if neg {
		sign_pref = '-'
	} else if sign_char == '+' {
		sign_pref = '+'
	} else if sign_char == ' ' {
		sign_pref = ' '
	}

	// Apply sign prefix if not already present
	if sign_pref != '' && out != '' && out[0] != `-` {
		out = sign_pref + out
	}

	// Apply width padding
	if width > out.len {
		pad_len := width - out.len
		padch := if zero_pad { '0' } else { ' ' }
		return padch.repeat(pad_len) + out
	}
	return out
}

// is_bool_expr returns true if `expr` is syntactically a boolean expression.
pub fn is_bool_expr(expr Expr) bool {
	match expr {
		BoolOp {
			return true
		}
		Compare {
			return true
		}
		UnaryOp {
			// not X is boolean
			return expr.op is Not
		}
		Constant {
			return expr.value is bool
		}
		else {
			return false
		}
	}
}

// bool_to_python_str returns a Python-style 'True'/'False' expression for `expr_str`.
pub fn bool_to_python_str(expr_str string) string {
	return "if ${expr_str} { 'True' } else { 'False' }"
}

// strip_outer_parens removes a single pair of outer parentheses if they wrap the whole expression `s`.
pub fn strip_outer_parens(s string) string {
	if s.len < 2 || s[0] != `(` || s[s.len - 1] != `)` {
		return s
	}
	// Check if the parens are balanced (they wrap the whole expression)
	mut depth := 0
	for i, c in s {
		if c == `(` {
			depth++
		} else if c == `)` {
			depth--
			// If depth becomes 0 before the end, parens don't wrap the whole thing
			if depth == 0 && i < s.len - 1 {
				return s
			}
		}
	}
	return s[1..s.len - 1]
}

// convert_percent_format converts a Python-style % format `fmt_str` with `values` into V interpolation.
pub fn convert_percent_format(fmt_str string, values []string) string {
	mut result := strings.new_builder(fmt_str.len * 2)
	result.write_u8(`'`)
	mut val_idx := 0
	mut i := 0

	for i < fmt_str.len {
		ch := fmt_str[i]
		if ch == `%` {
			i++
			if i >= fmt_str.len {
				break
			}
			if fmt_str[i] == `%` {
				result.write_u8(`%`)
				i++
				continue
			}

			// Parse flags: -, +, space, 0, #
			mut zero_pad := false
			mut left_align := false
			for i < fmt_str.len && fmt_str[i] in [`-`, `+`, ` `, `0`, `#`] {
				if fmt_str[i] == `0` {
					zero_pad = true
				}
				if fmt_str[i] == `-` {
					left_align = true
				}
				i++
			}
			// Python: left-align overrides zero-pad
			if left_align {
				zero_pad = false
			}

			// Parse width
			mut width := strings.new_builder(4)
			for i < fmt_str.len && fmt_str[i] >= `0` && fmt_str[i] <= `9` {
				width.write_u8(fmt_str[i])
				i++
			}

			// Parse precision (.N or bare . meaning 0)
			mut precision := strings.new_builder(4)
			mut has_dot := false
			if i < fmt_str.len && fmt_str[i] == `.` {
				has_dot = true
				i++
				for i < fmt_str.len && fmt_str[i] >= `0` && fmt_str[i] <= `9` {
					precision.write_u8(fmt_str[i])
					i++
				}
			}

			// Parse type character
			mut type_char := u8(0)
			if i < fmt_str.len {
				type_char = fmt_str[i]
				i++
			}

			if val_idx < values.len {
				value := values[val_idx]
				val_idx++

				w := width.str()
				p := precision.str()
				// V uses negative width for left-alignment
				effective_w := if left_align && w.len > 0 { '-${w}' } else { w }

				mut v_fmt := strings.new_builder(8)

				match type_char {
					`s` {
						if effective_w.len > 0 {
							v_fmt.write_string(':${effective_w}')
						}
					}
					`d`, `i` {
						if zero_pad && w.len > 0 {
							v_fmt.write_string(':0${effective_w}')
						} else if effective_w.len > 0 {
							v_fmt.write_string(':${effective_w}')
						}
					}
					`f`, `F` {
						// %.f = precision 0; bare %f = Python default 6
						actual_p := if p.len > 0 {
							p
						} else if has_dot {
							'0'
						} else {
							'6'
						}
						letter := if type_char == `F` { 'F' } else { 'f' }
						if effective_w.len > 0 {
							if zero_pad {
								v_fmt.write_string(':0${effective_w}.${actual_p}${letter}')
							} else {
								v_fmt.write_string(':${effective_w}.${actual_p}${letter}')
							}
						} else {
							v_fmt.write_string(':.${actual_p}${letter}')
						}
					}
					`e`, `E` {
						// %.e = precision 0; bare %e = Python default 6
						actual_p := if p.len > 0 {
							p
						} else if has_dot {
							'0'
						} else {
							'6'
						}
						letter := if type_char == `E` { 'E' } else { 'e' }
						if effective_w.len > 0 {
							v_fmt.write_string(':${effective_w}.${actual_p}${letter}')
						} else {
							v_fmt.write_string(':.${actual_p}${letter}')
						}
					}
					`g`, `G` {
						actual_p := if p.len > 0 {
							p
						} else if has_dot {
							'0'
						} else {
							'6'
						}
						letter := if type_char == `G` { 'G' } else { 'g' }
						if effective_w.len > 0 {
							v_fmt.write_string(':${effective_w}.${actual_p}${letter}')
						} else {
							v_fmt.write_string(':.${actual_p}${letter}')
						}
					}
					`x` {
						if effective_w.len > 0 {
							if zero_pad {
								v_fmt.write_string(':0${effective_w}x')
							} else {
								v_fmt.write_string(':${effective_w}x')
							}
						} else {
							v_fmt.write_string(':x')
						}
					}
					`X` {
						if effective_w.len > 0 {
							if zero_pad {
								v_fmt.write_string(':0${effective_w}X')
							} else {
								v_fmt.write_string(':${effective_w}X')
							}
						} else {
							v_fmt.write_string(':X')
						}
					}
					`o` {
						if effective_w.len > 0 {
							if zero_pad {
								v_fmt.write_string(':0${effective_w}o')
							} else {
								v_fmt.write_string(':${effective_w}o')
							}
						} else {
							v_fmt.write_string(':o')
						}
					}
					else {}
				}

				fmt_spec := v_fmt.str()
				result.write_u8(`$`)
				result.write_u8(`{`)
				result.write_string(value)
				result.write_string(fmt_spec)
				result.write_u8(`}`)
			}
		} else {
			// Escape characters that are special in V string literals
			match ch {
				`'` { result.write_string("\\'") }
				`$` { result.write_string('\\$') }
				`\\` { result.write_string('\\\\') }
				`\n` { result.write_string('\\n') }
				`\r` { result.write_string('\\r') }
				`\t` { result.write_string('\\t') }
				else { result.write_u8(ch) }
			}

			i++
		}
	}

	result.write_u8(`'`)
	return result.str()
}
