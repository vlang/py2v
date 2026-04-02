module main

import strings

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
