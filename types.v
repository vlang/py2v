module main

// V type mapping from Python types
pub const v_type_map = {
	'int':      'int'
	'float':    'f64'
	'str':      'string'
	'bool':     'bool'
	'Bool':     'bool' // SMT Bool type
	'bytes':    '[]u8'
	'tuple':    '[]int' // V doesn't have tuples, use arrays
	'c_int8':   'i8'
	'c_int16':  'i16'
	'c_int32':  'int'
	'c_int64':  'i64'
	'c_uint8':  'u8'
	'c_uint16': 'u16'
	'c_uint32': 'u32'
	'c_uint64': 'u64'
	'i8':       'i8'
	'i16':      'i16'
	'i32':      'int'
	'i64':      'i64'
	'u8':       'u8'
	'u16':      'u16'
	'u32':      'u32'
	'u64':      'u64'
	'None':     'Any'
}

// V container type mapping
pub const v_container_type_map = {
	'List':     '[]'
	'Dict':     'map'
	'Set':      '[]' // V doesn't have sets, use arrays
	'Optional': '?'
	'Tuple':    '[]' // V doesn't have tuples, use arrays
}

// V keywords that need escaping with @
pub const v_keywords = [
	'as',
	'asm',
	'assert',
	'atomic',
	'break',
	'const',
	'continue',
	'defer',
	'else',
	'enum',
	'false',
	'for',
	'fn',
	'__global',
	'go',
	'goto',
	'if',
	'import',
	'in',
	'interface',
	'is',
	'match',
	'module',
	'mut',
	'shared',
	'lock',
	'rlock',
	'none',
	'return',
	'select',
	'sizeof',
	'isreftype',
	'_likely_',
	'_unlikely_',
	'__offsetof',
	'struct',
	'true',
	'type',
	'typeof',
	'dump',
	'or',
	'union',
	'pub',
	'static',
	'unsafe',
]

// V built-in type names that conflict when used as identifiers (variable/parameter names)
// These need escaping with @ only in identifier context, not as type casts
pub const v_builtin_types = [
	'string',
	'int',
	'i8',
	'i16',
	'i64',
	'u8',
	'u16',
	'u32',
	'u64',
	'f32',
	'f64',
	'bool',
	'byte',
	'rune',
	'voidptr',
	'charptr',
	'byteptr',
]

// V width rank for numeric type promotion
pub const v_width_rank = {
	'bool': 0
	'i8':   1
	'u8':   2
	'byte': 2
	'i16':  3
	'u16':  4
	'int':  5
	'u32':  6
	'i64':  7
	'u64':  8
	'f32':  9
	'f64':  10
}

// Map Python AST operator names to V symbols
pub fn op_to_symbol(op_type string) string {
	return match op_type {
		'Eq' { '==' }
		'NotEq' { '!=' }
		'Lt' { '<' }
		'LtE' { '<=' }
		'Gt' { '>' }
		'GtE' { '>=' }
		'Is' { '==' }
		'IsNot' { '!=' }
		'In' { 'in' }
		'NotIn' { '!in' }
		'Add' { '+' }
		'Sub' { '-' }
		'Mult' { '*' }
		'Div' { '/' }
		'FloorDiv' { '/' }
		'Mod' { '%' }
		'Pow' { '^' } // Note: V uses ^ for power, not **
		'LShift' { '<<' }
		'RShift' { '>>' }
		'BitOr' { '|' }
		'BitXor' { '^' }
		'BitAnd' { '&' }
		'MatMult' { '*' } // No matrix mult in V, fallback to *
		'And' { '&&' }
		'Or' { '||' }
		'Not' { '!' }
		'Invert' { '~' }
		'UAdd' { '+' }
		'USub' { '-' }
		else { op_type }
	}
}

// Map Python type annotation to V type
pub fn map_type(typename string) string {
	if typename in v_type_map {
		return v_type_map[typename]
	}
	// Check if it's a container type (uppercase or PEP 585 lowercase)
	if typename.starts_with('List[') || typename.starts_with('list[') {
		inner := typename[typename.index_u8(`[`) + 1..typename.len - 1]
		return '[]${map_type(inner)}'
	}
	if typename.starts_with('Dict[') || typename.starts_with('dict[') {
		// Dict[K, V] / dict[K, V] -> map[K]V
		inner := typename[typename.index_u8(`[`) + 1..typename.len - 1]
		parts := split_type_args(inner)
		if parts.len == 2 {
			return 'map[${map_type(parts[0])}]${map_type(parts[1])}'
		}
	}
	if typename.starts_with('Optional[') {
		inner := typename[9..typename.len - 1]
		return '?${map_type(inner)}'
	}
	if typename.starts_with('Set[') || typename.starts_with('set[') {
		inner := typename[typename.index_u8(`[`) + 1..typename.len - 1]
		return '[]${map_type(inner)}' // V doesn't have sets
	}
	if typename.starts_with('Tuple[') || typename.starts_with('tuple[') {
		// Tuples become arrays in V
		return '[]Any'
	}
	// Unknown type, return as-is (might be a user-defined type)
	return typename
}

// Split type arguments like "str, int" into ["str", "int"]
fn split_type_args(s string) []string {
	mut result := []string{}
	mut depth := 0
	mut start := 0
	for i, c in s {
		if c == `[` {
			depth++
		} else if c == `]` {
			depth--
		} else if c == `,` && depth == 0 {
			result << s[start..i].trim_space()
			start = i + 1
		}
	}
	if start < s.len {
		result << s[start..].trim_space()
	}
	return result
}

// Check if a name is a V keyword
pub fn is_keyword(name string) bool {
	return name in v_keywords
}

// Escape a name if it's a V keyword
pub fn escape_keyword(name string) string {
	if is_keyword(name) {
		return '@${name}'
	}
	return name
}

// Escape a name used as an identifier (variable/parameter name) if it conflicts
// with V keywords or built-in type names
pub fn escape_identifier(name string) string {
	if is_keyword(name) || name in v_builtin_types {
		return '@${name}'
	}
	return name
}

// Get the wider type for binary operations
pub fn get_wider_type(left_type string, right_type string) string {
	left_rank := v_width_rank[left_type] or { -1 }
	right_rank := v_width_rank[right_type] or { -1 }
	if left_rank > right_rank {
		return left_type
	}
	return right_type
}

// Promote numeric type for add/mul operations (widens by one step)
pub fn promote_numeric_type(left_type string, right_type string, op string) string {
	// Float always wins
	if left_type == 'f64' || right_type == 'f64' || left_type == 'f32' || right_type == 'f32' {
		return 'f64'
	}

	// Sub keeps the wider type (no promotion)
	if op == 'Sub' {
		return get_wider_type(left_type, right_type)
	}

	// For Add, Mult: promote to next-wider type
	wider := get_wider_type(left_type, right_type)
	return match wider {
		'i8' { 'i16' }
		'u8' { 'u16' }
		'i16' { 'int' }
		'u16' { 'u32' }
		'int' { 'i64' }
		'u32' { 'u64' }
		'i64' { 'i64' }
		'u64' { 'u64' }
		else { wider }
	}
}

// Default type for unresolved types
pub const default_type = 'Any'
