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
	'Dict':     'map[string]Any'
	'list':     '[]Any' // a bare `list` annotation says nothing about its elements
	'List':     '[]Any'
	'set':      '[]Any'
	'Set':      '[]Any'
	'object':   'Any'
	'type':     'Any'
	'Type':     'Any'
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

// math_member_names gives the V spelling of a name imported from Python's
// math module, for the members V's math module has under the same meaning.
pub const math_member_names = {
	'pi':        'math.pi'
	'e':         'math.e'
	'tau':       'math.tau'
	'inf':       'math.inf(1)'
	'nan':       'math.nan()'
	'sqrt':      'math.sqrt'
	'sin':       'math.sin'
	'cos':       'math.cos'
	'tan':       'math.tan'
	'asin':      'math.asin'
	'acos':      'math.acos'
	'atan':      'math.atan'
	'atan2':     'math.atan2'
	'sinh':      'math.sinh'
	'cosh':      'math.cosh'
	'tanh':      'math.tanh'
	'exp':       'math.exp'
	'log':       'math.log'
	'log2':      'math.log2'
	'log10':     'math.log10'
	'hypot':     'math.hypot'
	'radians':   'math.radians'
	'degrees':   'math.degrees'
	// Integer functions: visit_call rewrites the call itself to V's integer
	// spelling, so the name only has to carry the module.
	'gcd':       'math.gcd'
	'isqrt':     'math.isqrt'
	'factorial': 'math.factorial'
}

// V container type mapping
pub const v_container_type_map = {
	'Dict':            'map'
	'Iterable':        '[]' // approximated by a V array
	'List':            '[]'
	'MutableSequence': '[]'
	'Optional':        '?'
	'Sequence':        '[]'
	'Set':             '[]' // V doesn't have sets, use arrays
	'Tuple':           '[]' // V doesn't have tuples, use arrays
	'dict':            'map' // Python 3.9+ lowercase generic
	'list':            '[]' // Python 3.9+ lowercase generic — parameterized form (see v_type_map for bare)
	'set':             '[]' // Python 3.9+ lowercase generic
	'tuple':           '[]' // Python 3.9+ lowercase generic
}

// V keywords that need escaping with @
pub const v_keywords = [..]string[
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
	'volatile',
]

// V built-in type names that conflict when used as identifiers (variable/parameter names)
// These need escaping with @ only in identifier context, not as type casts
pub const v_builtin_types = [..]string[
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
]

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
	return map_type_except(typename, []string{})
}

// map_type_except is map_type for a module that defines classes named in `classes`
// (Sequence, Iterable or Mapping): an annotation of such a class keeps its name.
pub fn map_type_except(typename string, classes []string) string {
	if typename in v_type_map {
		return v_type_map[typename]
	}
	// A bare `Callable` gives no parameters and no result: it has no V spelling.
	if typename == 'Callable' {
		return 'Any'
	}
	for head in ['Callable[', 'typing.Callable[', 'collections.abc.Callable['] {
		if !typename.starts_with(head) || !typename.ends_with(']') {
			continue
		}
		args := split_type_args(typename[head.len..typename.len - 1])
		if args.len != 2 || !args[0].starts_with('[') || !args[0].ends_with(']') {
			return 'fn (Any) Any'
		}
		params := split_type_args(args[0][1..args[0].len - 1]).map(map_type_except(it, classes))
		ret := if args[1] == 'None' { '' } else { ' ' + map_type_except(args[1], classes) }
		return 'fn (${params.join(', ')})${ret}'
	}
	// A bare `MutableSequence` is a bare `list`.
	if typename == 'MutableSequence' {
		return v_type_map['list']
	}
	// PEP 604 written as text (a field annotation or a quoted one): `X | None`
	// is an optional; any other union has no V spelling and becomes Any.
	// The union is split outside brackets only: in `dict[str, int] | None` the
	// members are the dict and None.
	if typename.contains(' | ') && split_union_members(typename).len > 1 {
		members := split_union_members(typename)
		rest := members.filter(it != 'None' && it != 'none')
		if rest.len == 1 && members.len == 2 {
			return '?' + map_type(rest[0])
		}
		return 'Any'
	}
	if classes.any(typename.starts_with('${it}[')) {
		return typename
	}
	for wrapper in ['ClassVar[', 'Final['] {
		if typename.starts_with(wrapper) && typename.ends_with(']') {
			return map_type_except(typename[wrapper.len..typename.len - 1], classes)
		}
	}
	if typename.starts_with('type[') || typename.starts_with('Type[') {
		return 'Any'
	}
	// Check if it's a container type (uppercase or PEP 585 lowercase)
	if typename.starts_with('List[') || typename.starts_with('list[')
		|| typename.starts_with('Sequence[') || typename.starts_with('Iterable[')
		|| typename.starts_with('MutableSequence[') {
		inner := typename[typename.index_u8(`[`) + 1..typename.len - 1]
		return '[]${map_type_except(inner, classes)}'
	}
	if typename.starts_with('Dict[') || typename.starts_with('dict[')
		|| typename.starts_with('Mapping[') {
		// Dict[K, V] / dict[K, V] -> map[K]V
		inner := typename[typename.index_u8(`[`) + 1..typename.len - 1]
		parts := split_type_args(inner)
		if parts.len == 2 {
			return 'map[${map_type_except(parts[0], classes)}]${map_type_except(parts[1], classes)}'
		}
	}
	if typename.starts_with('Optional[') {
		inner := typename[9..typename.len - 1]
		return '?${map_type_except(inner, classes)}'
	}
	if typename.starts_with('Set[') || typename.starts_with('set[') {
		inner := typename[typename.index_u8(`[`) + 1..typename.len - 1]
		return '[]${map_type_except(inner, classes)}' // V doesn't have sets
	}
	if typename.starts_with('Tuple[') || typename.starts_with('tuple[') {
		// Tuples become arrays in V
		return '[]Any'
	}
	// Unknown type, return as-is (might be a user-defined type)
	return typename
}

// split_union_members splits a union written as text at each ` | ` that is not
// inside brackets.
fn split_union_members(s string) []string {
	mut result := []string{}
	mut depth := 0
	mut start := 0
	for i, c in s {
		if c == `[` {
			depth++
		} else if c == `]` {
			depth--
		} else if c == `|` && depth == 0 && i > 0 && s[i - 1] == ` ` && i + 1 < s.len
			&& s[i + 1] == ` ` {
			result << s[start..i].trim_space()
			start = i + 1
		}
	}
	result << s[start..].trim_space()
	return result
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

// python_dunder_method_names maps Python dunder methods that V expresses as
// ordinary named methods rather than operators. V forbids a leading underscore
// on method names, so `__init__` becomes `init`.
pub const python_dunder_method_names = {
	'__floordiv__':  'py_floor_div'
	'__ne__':        'py_ne'
	'__le__':        'py_le'
	'__gt__':        'py_gt'
	'__ge__':        'py_ge'
	'__neg__':       'py_neg'
	'__pos__':       'py_pos'
	'__invert__':    'py_invert'
	'__init__':      'init'
	'__post_init__': 'post_init'
	'__enter__':     'enter'
	'__exit__':      'exit'
	'__new__':       'py2v_dunder_new'
	'__del__':       'del'
	// Numeric protocol hooks. V has no reserved spellings for these, and they
	// read better as explicit conversion methods than as mangled names.
	'__int__':       'py2v_dunder_int'
	'__repr__':      'py2v_dunder_repr'
	'__getitem__':   'py2v_dunder_getitem'
	'__contains__':  'py2v_dunder_contains'
	'__float__':     'to_float'
	'__bool__':      'to_bool'
	'__index__':     'to_index'
	'__hash__':      'hash_value'
	// Python module-level dunders with no V counterpart. V has no `__file__`
	// ambient value, so it is emitted as a name the caller can define, but the
	// name must still be a legal V identifier.
	'__file__':      'file___'
}

// python_dunder_class_attrs are Python bookkeeping class attributes that have no
// runtime meaning in V and must not become struct fields.
pub const python_dunder_class_attrs = ['__slots__', '__doc__', '__module__', '__qualname__', '__dict__',
	'__weakref__', '__annotations__', '__dataclass_fields__']!

// escape_leading_underscore maps a Python identifier that starts with `_` to a
// legal V identifier. V forbids a leading underscore on fields, methods, and
// local variables, while Python code uses `_name` for private-by-convention and
// dunders for protocol hooks. Leading underscores are moved to the end, which
// matches V's own shadow-avoidance convention (the same one escape_identifier
// uses for built-in type names): `_foo` becomes `foo_`, `__foo` becomes `foo__`.
//
// A bare `_` is the Python throwaway target and is left alone, since V accepts
// `_` as a discard name.
pub fn escape_leading_underscore(name string) string {
	if name == '_' {
		return name
	}
	// Reserve the prefix used below, including spellings reached by moving
	// leading underscores, so a Python name cannot shadow an encoded one.
	if name.trim_left('_').starts_with('py2v_numeric_') {
		return 'py2v_numeric_${name}'
	}
	if name.trim_left('_').starts_with('py2v_dunder_') {
		return 'py2v_dunder_${name}'
	}
	if name == '' || name[0] != `_` {
		return name
	}
	mut lead := 0
	for lead < name.len && name[lead] == `_` {
		lead++
	}
	rest := name[lead..]
	if rest.len == 0 {
		// All-underscore name such as `__`: V cannot express this, so use `_`.
		return '_'
	}
	if rest[0].is_digit() {
		return 'py2v_numeric${name}'
	}
	// `lead` underscores move to the end: `_foo` -> `foo_`, `__foo` -> `foo__`.
	return '${rest}${'_'.repeat(lead)}'
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
	// Reserved names are renamed identically on both sides, so that a
	// declaration and its references cannot drift apart.
	if name in v_reserved_idents {
		return '${name}_'
	}
	return escape_leading_underscore(name)
}

// v_reserved_idents are Python names that cannot be used verbatim for a V local
// or parameter.
//
// `v` is the V compiler's own namespace, importable as `v.abc` and friends. A
// local named `v` is emitted verbatim, `v fmt` then adds `import v` for the
// `v.something` it sees, and the module stops resolving. Only bare locals are
// affected: a struct field reached as `self.v` never looks like a module, so
// fields keep escape_leading_underscore and stay consistent with their uses.
//
// `char` is a V type name the compiler refuses as a variable or parameter name.
// `map` is also a V type name, and a bare `map {` starts a map literal.
const v_reserved_idents = ['v', 'sql', 'char', 'map']!

// v_reserved_fn_names are Python names that V reserves for its own C-backed
// intrinsics. A user `fn` declared under one of these names cannot be called at
// all: V reports `expression in `x` must be a function call` at the call site
// and never resolves it.
//
// `print` is deliberately absent. V reserves it as well, but py2v maps Python's
// `print()` to `println()`, and builtin dispatch matches on the unescaped name,
// so escaping it here would stop every `print` statement being recognised.
const v_reserved_fn_names = ['spawn', 'exit', 'malloc', 'free']!

// escape_fn_name renames a function to a spelling V will accept. A qualified
// name keeps its prefix, so `doebuild.spawn` becomes `doebuild.spawn_` and
// still reaches the module that declares it.
pub fn escape_fn_name(name string) string {
	i := name.last_index('.') or {
		// `Or(...)` looks like a cast and vfmt can change the argument list.
		// Escape its lowercased spelling when it would be a V keyword.
		lower := lower_first_ascii(name)
		if lower != name && is_keyword(lower) {
			return escape_keyword(lower)
		}
		return if name in v_reserved_fn_names {
			'${name}_'
		} else {
			name
		}
	}
	tail := name[i + 1..]
	if tail in v_reserved_fn_names {
		return name[..i + 1] + tail + '_'
	}
	return name
}

// escape_local_ident rewrites a Python name for use as a V local, parameter or
// reference. `escape_identifier` cannot be used for references because it also
// renames the Python builtins `int`, `bool` and `str`, which builtin dispatch
// matches on by name; this keeps the two declaration sites in agreement with it.
pub fn escape_local_ident(name string) string {
	if name in v_reserved_idents {
		return '${name}_'
	}
	return escape_keyword(escape_leading_underscore(name))
}

// escape_local_decl produces the V spelling of a Python name being declared as
// a variable or parameter.
//
// V rejects an uppercase letter anywhere in a variable or parameter name, while
// Python freely uses `Atom`, `_ForkWatcher` or `EI_CLASS` in those positions —
// mostly by passing a class as an argument or by naming a constant in SCREAMING
// CASE. Lowercasing is the only spelling V accepts.
//
// Callers must not apply this to a name that denotes a type: a class keeps its
// capitalisation so that references resolve to the declared struct.
pub fn escape_local_decl(name string) string {
	if name == '' {
		return name
	}
	// Lower first, then escape: `CONTINUE` must come out as `@continue`.
	// A leading underscore does not change the case rule: `_MAX` is `max_`.
	bare := name.trim_left('_')
	first := if bare.len > 0 { bare[0] } else { name[0] }
	if first >= `A` && first <= `Z` {
		return escape_identifier(name.to_lower())
	}
	return escape_identifier(name)
}

// zero_value_for_type returns a V expression of zero value for `typ`.
//
// A bare `x := <typ>{}` only makes sense for container types. For a scalar the
// `{}` suffix is not valid V at all (`a := bool{}` does not parse), so scalars
// get an explicit zero literal instead.
pub fn zero_value_for_type(typ string) string {
	if typ == '' {
		return 'Any{}'
	}
	if typ.starts_with('[]') || typ.starts_with('map[') || typ.starts_with('[') {
		return '${typ}{}'
	}
	if typ.starts_with('?') {
		return 'none'
	}
	if typ == 'string' {
		return "''"
	}
	if typ == 'bool' {
		return 'false'
	}
	if typ in ['f32', 'f64'] {
		return '0.0'
	}
	if typ in v_width_rank {
		return '0'
	}
	// User-defined struct or enum: its zero value.
	return '${typ}{}'
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
	'datetime':    '' // imported on use, from the runtime's manifest
	'enum':        ''
	'functools':   'arrays'
	'hashlib':     'crypto'
	'http':        '!// import http: use V net.http'
	'io':          'os'
	'itertools':   'arrays'
	'json':        'pyrt.json'
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
	'sqlite3':     'pyrt.sqlite3'
	'struct':      'encoding.binary'
	'subprocess':  'os'
	// errno/stat/signal/warnings are rewritten inline at the use site.
	'errno':       ''
	'stat':        ''
	'signal':      ''
	'warnings':    ''
	// fcntl has no V counterpart; its call sites become explanatory comments.
	'fcntl':       ''
	// suppress — no V equivalent needed
	'sys':         'os'
	'threading':   '!// import threading: use V goroutines (go fn(){})'
	'time':        'time'
	'types':       ''
	'typing':      ''
	'unittest':    '!// import unittest: use V built-in `assert` and `v test`'
	'urllib':      '!// import urllib: use V net.http'
}

// python_unmapped_members are `module.member` spellings with no V equivalent.
//
// Mapping a module is not enough: `subprocess` becomes V's `os` at module level,
// but `subprocess.Popen` has no member there, and emitting it produces a field
// access V cannot parse. Anything listed here is stubbed at the call site and
// reported in a module-scope TODO rather than emitted verbatim.
pub const python_unmapped_members = [
	// Python spawns processes through a Popen object; V runs a process directly.
	'subprocess.Popen',
	'subprocess.run',
	'subprocess.call',
	'subprocess.check_output',
	'subprocess.check_call',
	'subprocess.CalledProcessError',
	'subprocess.TimeoutExpired',
	'subprocess.PopenError',
	'subprocess.PIPE',
	'subprocess.STDOUT',
	'subprocess.STDERR',
	'subprocess.STIN',
	'subprocess.DEVNULL',
	// Python locks and threads have no direct V spelling; V uses sync and
	// goroutines, which are not interchangeable at a call site.
	'threading.Thread',
	'threading.Event',
	'threading.Lock',
	'threading.RLock',
	'threading.Condition',
	'threading.Semaphore',
	'threading.Timer',
	'multiprocessing.Process',
	'multiprocessing.Pipe',
	'multiprocessing.Queue',
	'multiprocessing.get_start_method',
	'multiprocessing.set_start_method',
	'multiprocessing.reduction',
	// Runtime introspection and platform probes.
	'platform.system',
	'platform.python_implementation',
	'platform.uname',
	'platform.machine',
	'platform.release',
	// Python's struct module packs binary records; V has no matching API, only
	// fixed-width encoding helpers.
	'struct.Struct',
	'struct.pack',
	'struct.unpack',
	'struct.calcsize',
	'struct.unpack_from',
	'struct.pack_into',
	// Constant tables V spells differently.
	'signal.SIG_DFL',
	'signal.SIG_IGN',
	'signal.SIGINT',
	'signal.SIGTERM',
	'signal.SIGKILL',
	'signal.SIGSTOP',
	'signal.SIGCONT',
	'signal.SIGALRM',
	'signal.SIGCHLD',
	'signal.SIGPIPE',
	'signal.SIGQUIT',
	'signal.SIGUSR1',
	'signal.SIGUSR2',
	'signal.SIGWINCH',
]!

// python_unmapped_names are bare Python callables with no V equivalent.
//
// The functional forms build a type at runtime, which V has no way to express.
// They are stubbed at the call site and reported, rather than emitted as a call
// to a name V will not accept.
pub const python_unmapped_names = [
	// Functional API Enum('Name', [...]) has no static V spelling.
	'Enum',
	'IntEnum',
	'Flag',
	'IntFlag',
	'unique',
	// struct.Struct(...) likewise.
	'Struct',
]!

// Python stdlib modules that py2v handles inline rather than by importing a V
// module. The value is the V module to import, or '' when the module's contents
// are rewritten at the use site and no import is needed.
pub const python_stdlib_inline_modules = ['errno', 'stat', 'signal', 'warnings']!

// stat_mode_predicates maps Python `stat.S_ISxxx(mode)` predicates to the POSIX
// file-type mask test expressed against V's `os.Stat.mode` (a raw u32).
//
// V has no `os.Stat.is_dir()` helper, so the test is inlined: a predicate is
// true when the file-type bits equal the expected value.
pub const stat_mode_masks = {
	'S_IFMT':   '0o170000'
	'S_IFSOCK': '0o140000'
	'S_IFLNK':  '0o120000'
	'S_IFREG':  '0o100000'
	'S_IFBLK':  '0o060000'
	'S_IFDIR':  '0o040000'
	'S_IFCHR':  '0o020000'
	'S_IFIFO':  '0o010000'
	'S_IMODE':  '0o7777'
}

// stat_mode_predicates are the `S_ISxxx` names, mapped to the mask they test.
pub const stat_mode_predicates = {
	'S_ISSOCK': 'S_IFSOCK'
	'S_ISLNK':  'S_IFLNK'
	'S_ISREG':  'S_IFREG'
	'S_ISBLK':  'S_IFBLK'
	'S_ISDIR':  'S_IFDIR'
	'S_ISCHR':  'S_IFCHR'
	'S_ISFIFO': 'S_IFIFO'
}

// stat_bit_predicates are the `S_ISxxx` names that test a single permission or
// set-id bit, which need no file-type masking.
pub const stat_bit_predicates = ['S_ISUID', 'S_ISGID', 'S_ISVTX']!
pub const stat_bit_masks = ['0o4000', '0o2000', '0o1000']!

// errno_values maps the Python errno constants portage checks against to their
// POSIX numeric values. V's os package does not expose errno constants, so the
// numbers are emitted directly; they are stable ABI values.
pub const errno_values = {
	'EPERM':        '1'
	'ENOENT':       '2'
	'ESRCH':        '3'
	'EINTR':        '4'
	'EIO':          '5'
	'ENXIO':        '6'
	'E2BIG':        '7'
	'ENOEXEC':      '8'
	'EBADF':        '9'
	'ECHILD':       '10'
	'EAGAIN':       '11'
	'ENOMEM':       '12'
	'EACCES':       '13'
	'EFAULT':       '14'
	'EBUSY':        '16'
	'EEXIST':       '17'
	'EXDEV':        '18'
	'ENODEV':       '19'
	'ENOTDIR':      '20'
	'EISDIR':       '21'
	'EINVAL':       '22'
	'ENFILE':       '23'
	'EMFILE':       '24'
	'ENOTTY':       '25'
	'ETXTBSY':      '26'
	'EFBIG':        '27'
	'ENOSPC':       '28'
	'ESPIPE':       '29'
	'EROFS':        '30'
	'EMLINK':       '31'
	'EPIPE':        '32'
	'EDOM':         '33'
	'ERANGE':       '34'
	'EDEADLK':      '35'
	'ENAMETOOLONG': '36'
	'ENOSYS':       '38'
	'ENOTEMPTY':    '39'
	'ELOOP':        '40'
	'ENOMSG':       '42'
	'EIDRM':        '43'
	'EOVERFLOW':    '75'
	'ESTALE':       '116'
	'EDQUOT':       '122'
	'ENOTSUP':      '95'
	'EOPNOTSUPP':   '95'
}

// signal_values maps Python signal names to V's `os.Signal` enum members. V uses
// POSIX numbering, so the mapping is a rename rather than a renumbering.
pub const signal_values = {
	'SIGHUP':    'os.Signal.hup'
	'SIGINT':    'os.Signal.int'
	'SIGQUIT':   'os.Signal.quit'
	'SIGILL':    'os.Signal.ill'
	'SIGTRAP':   'os.Signal.trap'
	'SIGABRT':   'os.Signal.abrt'
	'SIGBUS':    'os.Signal.bus'
	'SIGFPE':    'os.Signal.fpe'
	'SIGKILL':   'os.Signal.kill'
	'SIGUSR1':   'os.Signal.usr1'
	'SIGSEGV':   'os.Signal.segv'
	'SIGUSR2':   'os.Signal.usr2'
	'SIGPIPE':   'os.Signal.pipe'
	'SIGALRM':   'os.Signal.alrm'
	'SIGTERM':   'os.Signal.term'
	'SIGCHLD':   'os.Signal.chld'
	'SIGCONT':   'os.Signal.cont'
	'SIGSTOP':   'os.Signal.stop'
	'SIGTSTP':   'os.Signal.tstp'
	'SIGTTIN':   'os.Signal.ttin'
	'SIGTTOU':   'os.Signal.ttou'
	'SIGURG':    'os.Signal.urg'
	'SIGXCPU':   'os.Signal.xcpu'
	'SIGXFSZ':   'os.Signal.xfsz'
	'SIGVTALRM': 'os.Signal.vtalrm'
	'SIGPROF':   'os.Signal.prof'
	'SIGWINCH':  'os.Signal.winch'
	'SIGPOLL':   'os.Signal.poll'
	'SIGPWR':    'os.Signal.pwr'
	'SIGSYS':    'os.Signal.sys'
}

// signal_unrepresentable are Python signal sentinels with no V counterpart:
// V installs handlers only, and offers no default/ignore enum value.
pub const signal_unrepresentable = ['SIG_DFL', 'SIG_IGN', 'SIG_BLOCK', 'SIG_UNBLOCK', 'SIG_SETMASK']!

// fcntl_values are the advisory-lock modes. The V stdlib has no fcntl, so the
// accompanying calls are emitted as comments; these names are kept so a constant
// reference does not leak into the output as an unresolved identifier.
pub const fcntl_values = {
	'LOCK_SH':    '1'
	'LOCK_EX':    '2'
	'LOCK_NB':    '4'
	'LOCK_UN':    '8'
	'F_GETFD':    '1'
	'F_SETFD':    '2'
	'F_GETFL':    '3'
	'F_SETFL':    '4'
	'FD_CLOEXEC': '1'
}
