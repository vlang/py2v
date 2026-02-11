module main

import strings

// Indentation helper
pub fn indent(code string, level int, indent_str string) string {
	if code.len == 0 {
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

// Join strings with separator, filtering out empty strings
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

pub fn new_string_builder() StringBuilder {
	return StringBuilder{
		buf: strings.new_builder(1024)
	}
}

pub fn (mut sb StringBuilder) write(s string) {
	sb.buf.write_string(s)
}

pub fn (mut sb StringBuilder) writeln(s string) {
	sb.buf.write_string(s)
	sb.buf.write_string('\n')
}

pub fn (mut sb StringBuilder) str() string {
	return sb.buf.str()
}

// Check if a string looks like a number
pub fn is_numeric_string(s string) bool {
	if s.len == 0 {
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

// Escape string for V string literal
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

// Convert bytes to V byte array literal
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

// Check if expression is a simple literal (doesn't need parentheses)
pub fn is_simple_expr(expr_type string) bool {
	return expr_type in ['Constant', 'Name', 'Attribute', 'Subscript', 'Call', 'List', 'Dict',
		'Tuple']
}

// Generate unique temporary variable name
pub struct TmpVarGen {
mut:
	counter int
}

pub fn new_tmp_var_gen() TmpVarGen {
	return TmpVarGen{
		counter: 0
	}
}

pub fn (mut g TmpVarGen) next(prefix string) string {
	g.counter++
	return '__${prefix}${g.counter}'
}

// Check if a type is numeric
pub fn is_numeric_type(typ string) bool {
	return typ in v_width_rank
}

// Strip leading/trailing whitespace from each line
pub fn normalize_code(code string) string {
	lines := code.split('\n')
	mut result := []string{}
	for line in lines {
		trimmed := line.trim_right(' \t')
		result << trimmed
	}
	return result.join('\n')
}

// Wrap code in parentheses if needed
pub fn maybe_paren(code string, needs_paren bool) string {
	if needs_paren {
		return '(${code})'
	}
	return code
}

// Check if an expression is syntactically a boolean expression
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

// Wrap a boolean expression as Python-style True/False string
pub fn bool_to_python_str(expr_str string) string {
	return "if ${expr_str} { 'True' } else { 'False' }"
}

// Strip outer parentheses from expression if they wrap the entire expression
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
