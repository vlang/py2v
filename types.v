module main

// V type mapping from Python types
pub const v_type_map = {
	'Bool':     'bool' // SMT Bool type
	'None':     'Any'
	'bool':     'bool'
	'bytes':    '[]u8'
	'c_int16':  'i16'
	'c_int32':  'int'
	'c_int64':  'i64'
	'c_int8':   'i8'
	'c_uint16': 'u16'
	'c_uint32': 'u32'
	'c_uint64': 'u64'
	'c_uint8':  'u8'
	'complex':  'complex128'
	'dict':     'map[string]Any' // bare dict literal/type fallback
	'float':    'f64'
	'i16':      'i16'
	'i32':      'int'
	'i64':      'i64'
	'i8':       'i8'
	'int':      'int'
	'str':      'string'
	'tuple':    '[]int' // V doesn't have tuples, use arrays
	'u16':      'u16'
	'u32':      'u32'
	'u64':      'u64'
	'u8':       'u8'
}

// V container type mapping
pub const v_container_type_map = {
	'Dict':     'map'
	'List':     '[]'
	'Optional': '?'
	'Set':      '[]' // V doesn't have sets, use arrays
	'Tuple':    '[]' // V doesn't have tuples, use arrays
	'dict':     'map' // Python 3.9+ lowercase generic
	'list':     '[]' // Python 3.9+ lowercase generic — parameterized form (see v_type_map for bare)
	'set':      '[]' // Python 3.9+ lowercase generic
	'tuple':    '[]' // Python 3.9+ lowercase generic
}

// V keywords that need escaping with @
pub const v_keywords = [
	'__global',
	'__offsetof',
	'_likely_',
	'_unlikely_',
	'as',
	'asm',
	'assert',
	'atomic',
	'break',
	'const',
	'continue',
	'defer',
	'dump',
	'else',
	'enum',
	'false',
	'fn',
	'for',
	'go',
	'goto',
	'if',
	'import',
	'in',
	'interface',
	'is',
	'isreftype',
	'lock',
	'match',
	'module',
	'mut',
	'none',
	'or',
	'pub',
	'return',
	'rlock',
	'select',
	'shared',
	'sizeof',
	'static',
	'struct',
	'true',
	'type',
	'typeof',
	'union',
	'unsafe',
]!

// V built-in type names that conflict when used as identifiers (variable/parameter names)
// These need escaping with @ only in identifier context, not as type casts
pub const v_builtin_types = [
	'bool',
	'byte',
	'byteptr',
	'charptr',
	'f32',
	'f64',
	'i16',
	'i64',
	'i8',
	'int',
	'rune',
	'string',
	'u16',
	'u32',
	'u64',
	'u8',
	'voidptr',
]!

// V width rank for numeric type promotion
pub const v_width_rank = {
	'bool': 0
	'byte': 2
	'f32':  9
	'f64':  10
	'i16':  3
	'i64':  7
	'i8':   1
	'int':  5
	'u16':  4
	'u32':  6
	'u64':  8
	'u8':   2
}

// op_to_symbol maps Python AST operator names to V symbols.
pub fn op_to_symbol(op_type string) string {
	return match op_type {
		'Add' { '+' }
		'And' { '&&' }
		'BitAnd' { '&' }
		'BitOr' { '|' }
		'BitXor' { '^' }
		'Div' { '/' }
		'Eq' { '==' }
		'FloorDiv' { '/' } // Not floor division in V, handled in visit_binop/visit_aug_assign
		'Gt' { '>' }
		'GtE' { '>=' }
		'In' { 'in' }
		'Invert' { '~' }
		'Is' { '==' }
		'IsNot' { '!=' }
		'LShift' { '<<' }
		'Lt' { '<' }
		'LtE' { '<=' }
		'MatMult' { '*' } // No matrix mult in V, fallback to *
		'Mod' { '%' }
		'Mult' { '*' }
		'Not' { '!' }
		'NotEq' { '!=' }
		'NotIn' { '!in' }
		'Or' { '||' }
		'Pow' { '**' } // Not a V operator, handled in visit_binop/visit_aug_assign
		'RShift' { '>>' }
		'Sub' { '-' }
		'UAdd' { '+' }
		'USub' { '-' }
		else { op_type }
	}
}

// map_type maps a Python type annotation string to a V type string.
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

// split_type_args splits type arguments like "str, int" into ["str", "int"].
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

// is_keyword returns true if `name` is a V keyword.
pub fn is_keyword(name string) bool {
	return name in v_keywords
}

// escape_keyword escapes `name` with @ if it's a V keyword.
pub fn escape_keyword(name string) string {
	if is_keyword(name) {
		return '@${name}'
	}
	return name
}

// escape_identifier escapes names that conflict with V keywords or built-in type names.
pub fn escape_identifier(name string) string {
	if is_keyword(name) {
		return '@${name}'
	}
	// V built-in type names can't use @ prefix — rename with underscore suffix
	if name in v_builtin_types {
		return '${name}_'
	}
	return name
}

// get_wider_type returns the wider numeric type for binary operations.
pub fn get_wider_type(left_type string, right_type string) string {
	left_rank := v_width_rank[left_type] or { -1 }
	right_rank := v_width_rank[right_type] or { -1 }
	if left_rank > right_rank {
		return left_type
	}
	return right_type
}

// promote_numeric_type promotes numeric types for operations like Add/Mult.
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
		'i16' { 'int' }
		'i64' { 'i64' }
		'i8' { 'i16' }
		'int' { 'i64' }
		'u16' { 'u32' }
		'u32' { 'u64' }
		'u64' { 'u64' }
		'u8' { 'u16' }
		else { wider }
	}
}

// Default type for unresolved types
pub const default_type = 'Any'

// python_to_v_import maps well-known Python module names to their V equivalents.
// An empty string means "suppress silently" (typing, abc, etc.).
// A '!' prefix means "emit comment only" (no direct V equivalent).
pub const python_to_v_import = {
	// stdlib with direct V counterparts
	'__future__':  ''
	'abc':         ''
	'argparse':    'flag'
	'asyncio':     '!// import asyncio: use V goroutines and channels'
	'base64':      'encoding.base64'
	'builtins':    ''
	'cmath':       'math.complex'
	'collections': 'datatypes'
	'contextlib':  ''
	'copy':        ''
	'csv':         '!// import csv: use V csv or manual parsing'
	'dataclasses': ''
	'enum':        ''
	'functools':   'arrays'
	'hashlib':     'crypto'
	'http':        '!// import http: use V net.http'
	'io':          'os'
	'itertools':   'arrays'
	'json':        'json'
	'logging':     'log'
	'math':        'math'
	'os':          'os'
	'os.path':     'os'
	'pathlib':     'os'
	'pytest':      '!// import pytest: use V built-in `assert` and `v test`'
	'random':      'rand'
	're':          'regex'
	'requests':    '!// import requests: use V net.http'
	'shutil':      'os'
	'socket':      '!// import socket: use V net module'
	'sqlite3':     'db.sqlite'
	'struct':      'encoding.binary'
	'subprocess':  'os'
	// suppress — no V equivalent needed
	'sys':         'os'
	'threading':   '!// import threading: use V goroutines (go fn(){})'
	'time':        'time'
	'types':       ''
	'typing':      ''
	'unittest':    '!// import unittest: use V built-in `assert` and `v test`'
	'urllib':      '!// import urllib: use V net.http'
}
