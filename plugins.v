module main

// Dispatch table for built-in functions that need special handling
// Returns (result, handled) - if handled is false, fall back to default call handling

// Handle range() call
// Note: range expressions like `0..n` only work in for loops, not as expressions
// When used as an expression, we return an array initializer
fn visit_range(args []string) (string, bool) {
	if args.len == 1 {
		return '[]int{len: ${args[0]}, init: index}', true
	}
	if args.len == 2 {
		return '[]int{len: ${args[1]} - ${args[0]}, init: index + ${args[0]}}', true
	}
	if args.len == 3 {
		return '[]int{len: (${args[1]} - ${args[0]}) / ${args[2]}, init: ${args[0]} + index * ${args[2]}}', true
	}
	return '', false
}

// Handle print() call
fn visit_print(t &VTranspiler, node Call, args []string) (string, bool) {
	if args.len == 0 {
		return "println('')", true
	}

	// Check if all arguments are string constants - can be combined
	mut all_string_literals := true
	mut string_parts := []string{}

	for i, arg in node.args {
		if arg is Constant {
			c := arg as Constant
			if c.value is string {
				// Strip the quotes from the arg string
				arg_str := args[i]
				if arg_str.len >= 2 && arg_str.starts_with("'") && arg_str.ends_with("'") {
					string_parts << arg_str[1..arg_str.len - 1]
				} else {
					string_parts << arg_str
				}
				continue
			}
		}
		all_string_literals = false
		break
	}

	if all_string_literals && string_parts.len > 0 {
		// Combine string literals with spaces
		return "println('${string_parts.join(' ')}')", true
	}

	// Fall back to converting each part
	mut parts := []string{}
	for i, arg in node.args {
		arg_str := args[i]
		// Check if the argument is a string constant
		if arg is Constant {
			c := arg as Constant
			if c.value is string {
				// String literal - use as is
				parts << arg_str
				continue
			}
			// Bool constants need Python-style True/False
			if c.value is bool {
				parts << bool_to_python_str(arg_str)
				continue
			}
			// Numeric constants need parentheses for .str()
			parts << '(${arg_str}).str()'
			continue
		}

		// Check if argument has string annotation (e.g., IfExp returning strings)
		ann := get_v_annotation(arg)
		if ann == 'string' {
			parts << arg_str
			continue
		}

		// Check if it's an IfExp (bool-to-string conversion from frontend)
		if arg is IfExp {
			// IfExp with string body/orelse - already a string
			ifexp := arg as IfExp
			if ifexp.body is Constant {
				c := ifexp.body as Constant
				if c.value is string {
					// This is a bool-to-string conversion, use directly
					parts << arg_str
					continue
				}
			}
		}

		// Check if this is a boolean expression (BoolOp, Compare, not X)
		if is_bool_expr(arg) {
			parts << bool_to_python_str(arg_str)
			continue
		}

		// Check if this is a Name that refers to a known bool variable
		if arg is Name {
			n := arg as Name
			if t.var_types[n.id] == 'bool' {
				parts << bool_to_python_str(arg_str)
				continue
			}
			// Check if Name refers to a known string variable
			if t.var_types[n.id] == 'string' {
				parts << arg_str
				continue
			}
		}

		// Check if this is a Call to a function with known string return type
		if arg is Call {
			call := arg as Call
			if call.func is Name {
				fn_name := (call.func as Name).id
				ret_type := t.func_return_types[fn_name]
				if ret_type == 'string' {
					parts << arg_str
					continue
				}
				if ret_type == 'bool' {
					parts << bool_to_python_str(arg_str)
					continue
				}
			}
		}

		// Use infer_expr_type for more complex expressions
		inferred := t.infer_expr_type(arg)
		if inferred == 'string' {
			parts << arg_str
			continue
		}
		if inferred == 'bool' {
			parts << bool_to_python_str(arg_str)
			continue
		}

		// Non-string - need to convert with .str()
		// Name nodes don't need parens, but Attribute/Subscript and other expressions do
		needs_parens := arg !is Name
		if needs_parens {
			parts << '(${arg_str}).str()'
		} else {
			parts << '${arg_str}.str()'
		}
	}

	if parts.len == 1 {
		return 'println(${parts[0]})', true
	}

	// Join with spaces using string interpolation
	return 'println(${parts.join(" + ' ' + ")})', true
}

// Handle bool() call
fn visit_bool(t &VTranspiler, node Call, args []string) (string, bool) {
	if args.len == 0 {
		return 'false', true
	}
	// Check if argument is numeric - return boolean expression
	if node.args.len > 0 {
		ann := get_v_annotation(node.args[0])
		if ann in v_width_rank {
			return '(${args[0]} != 0)', true
		}
		// Check for string - empty string is false
		if ann == 'string' {
			return '(${args[0]}.len > 0)', true
		}
		// Use infer_expr_type as fallback
		inferred := t.infer_expr_type(node.args[0])
		if inferred in ['int', 'i64', 'f64', 'i8', 'i16', 'u8', 'u16', 'u32', 'u64'] {
			return '(${args[0]} != 0)', true
		}
		if inferred == 'string' {
			return '(${args[0]}.len > 0)', true
		}
	}
	return '(${args[0]} != 0)', true // Default to numeric comparison
}

// Handle int() call
fn visit_int(node Call, args []string) (string, bool) {
	if args.len == 0 {
		return '0', true
	}
	// Check if argument is a string - V uses '42'.int() syntax
	if node.args.len > 0 {
		if node.args[0] is Constant {
			c := node.args[0] as Constant
			if c.value is string {
				return '${args[0]}.int()', true
			}
		}
		ann := get_v_annotation(node.args[0])
		if ann == 'string' {
			return '${args[0]}.int()', true
		}
	}
	return 'int(${args[0]})', true
}

// Handle float() call
fn visit_float(node Call, args []string) (string, bool) {
	if args.len == 0 {
		return '0.0', true
	}
	// Check if argument is a string - V uses '3.14'.f64() syntax
	if node.args.len > 0 {
		if node.args[0] is Constant {
			c := node.args[0] as Constant
			if c.value is string {
				return '${args[0]}.f64()', true
			}
		}
		ann := get_v_annotation(node.args[0])
		if ann == 'string' {
			return '${args[0]}.f64()', true
		}
	}
	return 'f64(${args[0]})', true
}

// Handle str() call
fn visit_str(args []string) (string, bool) {
	if args.len == 0 {
		return "''", true
	}
	arg := args[0]
	// Simple identifiers don't need parens
	if arg.len > 0 && is_simple_identifier(arg) {
		return '${arg}.str()', true
	}
	return '(${arg}).str()', true
}

fn is_simple_identifier(s string) bool {
	if s.len == 0 {
		return false
	}
	// Check if it's a simple identifier (letters, digits, underscores, starting with letter/underscore)
	first := s[0]
	if !(first >= `a` && first <= `z`) && !(first >= `A` && first <= `Z`) && first != `_` {
		return false
	}
	for c in s {
		if !(c >= `a` && c <= `z`) && !(c >= `A` && c <= `Z`) && !(c >= `0` && c <= `9`) && c != `_` {
			return false
		}
	}
	return true
}

// Handle len() call
fn visit_len(args []string) (string, bool) {
	if args.len == 0 {
		return '0', true
	}
	return '${args[0]}.len', true
}

// Handle min() call - returns result and required import
fn visit_min(args []string) (string, bool, string) {
	if args.len == 1 {
		return "arrays.min(${args[0]}) or { panic('!') }", true, 'arrays'
	}
	return "arrays.min([${args.join(', ')}]) or { panic('!') }", true, 'arrays'
}

// Handle max() call
fn visit_max(args []string) (string, bool, string) {
	if args.len == 1 {
		return "arrays.max(${args[0]}) or { panic('!') }", true, 'arrays'
	}
	return "arrays.max([${args.join(', ')}]) or { panic('!') }", true, 'arrays'
}

// Handle abs() call
fn visit_abs(args []string) (string, bool, string) {
	return 'math.abs(${args[0]})', true, 'math'
}

// Handle round() call
fn visit_round(args []string) (string, bool, string) {
	return 'math.round(${args[0]})', true, 'math'
}

// Handle floor() call
fn visit_floor(args []string) (string, bool, string) {
	return 'int(math.floor(${args[0]}))', true, 'math'
}

// Handle pow() call
fn visit_pow(args []string) (string, bool, string) {
	return 'math.pow(${args[0]}, ${args[1]})', true, 'math'
}

// Handle sum() call
fn visit_sum(args []string) (string, bool, string) {
	return 'arrays.sum(${args[0]}) or { 0 }', true, 'arrays'
}

// Handle sorted() call
fn visit_sorted(args []string) (string, bool) {
	return '(fn (a []Any) []Any { mut b := a.clone(); b.sort(); return b }(${args[0]}))', true
}

// Handle map() call (not V's map data structure)
fn visit_map_builtin(args []string) (string, bool) {
	if args.len < 2 {
		return '', false
	}
	// map(func, iterable) -> iterable.map(func)
	return '${args[1]}.map(${args[0]})', true
}

// Handle filter() call
fn visit_filter(args []string) (string, bool) {
	if args.len < 2 {
		return '', false
	}
	// filter(func, iterable) -> iterable.filter(func)
	return '${args[1]}.filter(${args[0]})', true
}

// Handle all() call
fn visit_all(args []string) (string, bool) {
	return '${args[0]}.all(it)', true
}

// Handle any() call (builtin, not the type)
fn visit_any_builtin(args []string) (string, bool) {
	return '${args[0]}.any(it)', true
}

// Handle enumerate() call
fn visit_enumerate(args []string) (string, bool) {
	if args.len == 0 {
		return '[]Any{}', true
	}
	return args[0], true
}

// Handle zip() call
fn visit_zip(args []string) (string, bool) {
	return '[]Any{}', true
}

// Handle open() call
fn visit_open(args []string) (string, bool, string) {
	if args.len > 1 {
		mode := args[1].replace("'", '').replace('"', '')
		if mode.contains('w') {
			return 'os.create(${args[0]}) or { panic(err) }', true, 'os'
		}
	}
	return 'os.open(${args[0]}) or { panic(err) }', true, 'os'
}

// Handle input() call
fn visit_input(args []string) (string, bool, string) {
	if args.len > 0 {
		return 'os.input(${args[0]})', true, 'os'
	}
	return "os.input('')", true, 'os'
}

// Handle type() call
fn visit_type_fn(args []string) (string, bool) {
	return 'typeof(${args[0]}).name', true
}

// Handle id() call
fn visit_id(args []string) (string, bool) {
	return 'ptr_str(${args[0]})', true
}

// Handle isinstance() call
fn visit_isinstance(args []string) (string, bool) {
	return '${args[0]} is ${args[1]}', true
}

// Handle list() call
fn visit_list_fn(args []string) (string, bool) {
	if args.len == 0 {
		return '[]', true
	}
	return args[0], true
}

// Handle tuple() call
fn visit_tuple_fn(args []string) (string, bool) {
	if args.len == 0 {
		return '[]', true
	}
	return args[0], true
}

// Handle set() call
fn visit_set_fn(args []string) (string, bool) {
	if args.len == 0 {
		return '[]', true
	}
	return args[0], true
}

// Handle dict() call
fn visit_dict_fn(args []string) (string, bool) {
	if args.len == 0 {
		return '{}', true
	}
	return args[0], true
}

// Handle divmod() call
fn visit_divmod(args []string) (string, bool) {
	return '(${args[0]} / ${args[1]}, ${args[0]} % ${args[1]})', true
}

// Handle ord() call - get unicode code point of character
fn visit_ord(args []string) (string, bool) {
	return '${args[0]}[0]', true
}

// Handle chr() call - get character from code point
fn visit_chr(args []string) (string, bool) {
	return 'rune(${args[0]}).str()', true
}

// Handle reversed() call
fn visit_reversed(args []string) (string, bool) {
	return '${args[0]}.reverse()', true
}

// Handle sys.exit() call
fn visit_sys_exit(args []string) (string, bool) {
	if args.len == 0 {
		return 'exit(0)', true
	}
	return 'exit(${args[0]})', true
}

// DispatchResult holds the result of a dispatch
struct DispatchResult {
	code    string
	handled bool
	using   string
}

// Dispatch function that routes to the appropriate handler
pub fn dispatch_builtin(mut t VTranspiler, fname string, node Call, args []string) (string, bool) {
	result := dispatch_builtin_impl(t, fname, node, args)
	if result.handled && result.using.len > 0 {
		t.add_using(result.using)
	}
	return result.code, result.handled
}

fn dispatch_builtin_impl(t &VTranspiler, fname string, node Call, args []string) DispatchResult {
	match fname {
		'range' {
			code, handled := visit_range(args)
			return DispatchResult{code, handled, ''}
		}
		'print' {
			code, handled := visit_print(t, node, args)
			return DispatchResult{code, handled, ''}
		}
		'bool' {
			code, handled := visit_bool(t, node, args)
			return DispatchResult{code, handled, ''}
		}
		'int' {
			code, handled := visit_int(node, args)
			return DispatchResult{code, handled, ''}
		}
		'float' {
			code, handled := visit_float(node, args)
			return DispatchResult{code, handled, ''}
		}
		'str' {
			code, handled := visit_str(args)
			return DispatchResult{code, handled, ''}
		}
		'len' {
			code, handled := visit_len(args)
			return DispatchResult{code, handled, ''}
		}
		'min' {
			code, handled, using := visit_min(args)
			return DispatchResult{code, handled, using}
		}
		'max' {
			code, handled, using := visit_max(args)
			return DispatchResult{code, handled, using}
		}
		'abs' {
			code, handled, using := visit_abs(args)
			return DispatchResult{code, handled, using}
		}
		'round' {
			code, handled, using := visit_round(args)
			return DispatchResult{code, handled, using}
		}
		'floor' {
			code, handled, using := visit_floor(args)
			return DispatchResult{code, handled, using}
		}
		'pow' {
			code, handled, using := visit_pow(args)
			return DispatchResult{code, handled, using}
		}
		'sum' {
			code, handled, using := visit_sum(args)
			return DispatchResult{code, handled, using}
		}
		'sorted' {
			code, handled := visit_sorted(args)
			return DispatchResult{code, handled, ''}
		}
		'map' {
			code, handled := visit_map_builtin(args)
			return DispatchResult{code, handled, ''}
		}
		'filter' {
			code, handled := visit_filter(args)
			return DispatchResult{code, handled, ''}
		}
		'all' {
			code, handled := visit_all(args)
			return DispatchResult{code, handled, ''}
		}
		'any' {
			code, handled := visit_any_builtin(args)
			return DispatchResult{code, handled, ''}
		}
		'enumerate' {
			code, handled := visit_enumerate(args)
			return DispatchResult{code, handled, ''}
		}
		'zip' {
			code, handled := visit_zip(args)
			return DispatchResult{code, handled, ''}
		}
		'open' {
			code, handled, using := visit_open(args)
			return DispatchResult{code, handled, using}
		}
		'input' {
			code, handled, using := visit_input(args)
			return DispatchResult{code, handled, using}
		}
		'type' {
			code, handled := visit_type_fn(args)
			return DispatchResult{code, handled, ''}
		}
		'id' {
			code, handled := visit_id(args)
			return DispatchResult{code, handled, ''}
		}
		'isinstance' {
			code, handled := visit_isinstance(args)
			return DispatchResult{code, handled, ''}
		}
		'list' {
			code, handled := visit_list_fn(args)
			return DispatchResult{code, handled, ''}
		}
		'tuple' {
			code, handled := visit_tuple_fn(args)
			return DispatchResult{code, handled, ''}
		}
		'set' {
			code, handled := visit_set_fn(args)
			return DispatchResult{code, handled, ''}
		}
		'dict' {
			code, handled := visit_dict_fn(args)
			return DispatchResult{code, handled, ''}
		}
		'divmod' {
			code, handled := visit_divmod(args)
			return DispatchResult{code, handled, ''}
		}
		'sys.exit' {
			code, handled := visit_sys_exit(args)
			return DispatchResult{code, handled, ''}
		}
		'ord' {
			code, handled := visit_ord(args)
			return DispatchResult{code, handled, ''}
		}
		'chr' {
			code, handled := visit_chr(args)
			return DispatchResult{code, handled, ''}
		}
		'reversed' {
			code, handled := visit_reversed(args)
			return DispatchResult{code, handled, ''}
		}
		else {
			return DispatchResult{'', false, ''}
		}
	}
}

// Dispatch for attribute accesses like sys.argv
pub fn dispatch_attr(mut t VTranspiler, attr_path string) (string, bool) {
	match attr_path {
		'sys.argv' {
			t.add_using('os')
			return 'os.args', true
		}
		else {
			return '', false
		}
	}
}

// Get V annotation from an expression
fn get_v_annotation(expr Expr) string {
	match expr {
		Constant { return expr.v_annotation or { '' } }
		Name { return expr.v_annotation or { '' } }
		BinOp { return expr.v_annotation or { '' } }
		UnaryOp { return expr.v_annotation or { '' } }
		BoolOp { return expr.v_annotation or { '' } }
		Compare { return expr.v_annotation or { '' } }
		Call { return expr.v_annotation or { '' } }
		Attribute { return expr.v_annotation or { '' } }
		Subscript { return expr.v_annotation or { '' } }
		List { return expr.v_annotation or { '' } }
		Tuple { return expr.v_annotation or { '' } }
		Dict { return expr.v_annotation or { '' } }
		Set { return expr.v_annotation or { '' } }
		else { return '' }
	}
}
