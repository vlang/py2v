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
fn visit_print(mut t VTranspiler, node Call, args []string) (string, bool) {
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
	mut trailing_comments := []string{}
	for i, arg in node.args {
		// Special-case: some callers use string_literal.format(...)
		// We prefer to emit the base string and place a trailing comment
		// after the println when .format() is not supported, e.g.,
		// println(('...').str()) //.format(...)
		mut arg_str := args[i]
		// If the previously-generated expr string already contains an inline
		// "+ // .format(...)" comment (created by visit_call for .format),
		// move that comment to trailing_comments so it becomes an end-of-line
		// comment after the println instead of inside the expression.
		pos := arg_str.index('// .format(') or { -1 }
		if pos >= 0 {
			// split at the '//' start
			slash := arg_str.index('//') or { -1 }
			if slash >= 0 {
				base := arg_str[0..slash].trim_space()
				comm := arg_str[slash..].trim_space()
				arg_str = base
				trailing_comments << comm
			}
		}
		mut arg_node := arg
		mut arg_str_proc := arg_str
		if arg is Call {
			call := arg as Call
			if call.func is Attribute {
				attr := call.func as Attribute
				if attr.attr == 'format' {
					// Try to convert .format(...) to V interpolation by letting the
					// main visitor handle the Call. This returns a V string literal
					// with ${...} interpolations when possible.
					arg_node = call
					arg_str_proc = t.visit_expr(call)
					// Do not emit a trailing comment when conversion succeeded.
				}
			}
		}
		// Check if the argument is a string constant
		if arg_node is Constant {
			c := arg_node as Constant
			if c.value is string {
				// String literal - use as is (use processed arg_str)
				// Do not append .str() — emit the processed argument expression directly.
				parts << arg_str_proc
				continue
			}
			// Bool constants need Python-style True/False
			if c.value is bool {
				parts << bool_to_python_str(arg_str_proc)
				continue
			}
			// Numeric constants: emit as-is (V prints numerics without needing .str())
			parts << arg_str_proc
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

		// Non-string: emit expression as-is so printing relies on V's default
		// formatting/printing behavior.
		parts << arg_str
	}

	// Build final println with any trailing comments collected from .format fallbacks
	mut println_code := ''
	if parts.len == 1 {
		println_code = 'println(${parts[0]})'
	} else {
		// Join with spaces using string interpolation
		println_code = 'println(${parts.join(" + ' ' + ")})'
	}
	if trailing_comments.len > 0 {
		println_code = '${println_code} ${trailing_comments.join(' ')}'
	}
	return println_code, true
}

// Handle bool() call
fn visit_bool(mut t VTranspiler, node Call, args []string) (string, bool) {
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
	// Simple identifiers don't need parens — emit identifier or parenthesised expression
	if arg.len > 0 && is_simple_identifier(arg) {
		return '${arg}', true
	}
	return '(${arg})', true
}

fn is_simple_identifier(s string) bool {
	if s == '' {
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
	if args.len >= 2 {
		return 'math.round_sig(${args[0]}, ${args[1]})', true, 'math'
	}
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

// build_typed_lambda_closure builds a typed closure string from a Lambda AST node
// using frontend-provided annotations (v_annotation on lambda return or arg annotations)
// and fallbacks (infer iterable element type). `iter` is the iterable Expr used to infer
// parameter types when arg annotations are missing.
fn build_typed_lambda_closure(mut t VTranspiler, lam Lambda, iter Expr) string {
	mut params := []string{}
	// Try to infer element type from iterable as a fallback
	elem_type := t.infer_iter_elem_type(iter)
	for a in lam.args.args {
		// Default to Any
		mut ptype := 'Any'
		if ann := a.annotation {
			// Unwrap optional annotation into `ann` and use it
			ptype = t.typename_from_annotation(ann)
		} else if elem_type.len > 0 {
			ptype = elem_type
		} else {
			// keep Any
			ptype = 'Any'
		}
		name := escape_identifier(a.arg)
		params << '${name} ${ptype}'
	}
	// Determine return type: infer from lambda body. To allow the body to be
	// inferred correctly when parameters are unannotated, temporarily bind
	// the inferred/annotated parameter types into t.var_types while calling
	// infer_expr_type, then restore the original map.
	mut ret_type := 'Any'
	// Save original var_types so we can restore after inference
	orig_var_types := t.var_types.clone()
	// Populate param types for inference
	for a in lam.args.args {
		name := escape_identifier(a.arg)
		if ann := a.annotation {
			// Unwrap optional annotation into `ann` and use it
			t.var_types[name] = t.typename_from_annotation(ann)
		} else if elem_type.len > 0 {
			t.var_types[name] = elem_type
		}
	}
	inferred := t.infer_expr_type(lam.body)
	// Restore original var_types (use clone to avoid move/copy errors)
	t.var_types = orig_var_types.clone()
	if inferred.len > 0 {
		ret_type = inferred
	}
	// Render body expression
	body := t.visit_expr(lam.body)
	stripped := strip_outer_parens(body)
	return 'fn (${params.join(', ')}) ${ret_type} {\n\treturn ${stripped}\n}'
}

// Handle all() call
fn visit_all(args []string) (string, bool) {
	return '${args[0]}.all(it)', true
}

// Handle any() call (builtin, not the type)
fn visit_any_builtin(args []string) (string, bool) {
	return '${args[0]}.any(it)', true
}

// Handle enumerate() call — in expression context emit indexed array of tuples.
// The for-loop case (for i, v in enumerate(x)) is handled directly in visit_for.
fn visit_enumerate(args []string) (string, bool) {
	if args.len == 0 {
		return '[]', true
	}
	// Emit IIFE that builds [(0,v0),(1,v1),...] as a [][]Any
	iter := args[0]
	return '(fn () [][]Any { mut r := [][]Any{}; for i, v in ${iter} { r << [Any(i), v] }; return r }())', true
}

// Handle zip() call — maps to arrays.group() in expression context.
// The for-loop case (for a, b in zip(x, y)) is handled directly in visit_for.
fn visit_zip(args []string) (string, bool) {
	if args.len == 0 {
		return '[][]Any{}', true
	}
	return 'arrays.group(${args.join(', ')})', true
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

// Handle getattr(obj, name) / getattr(obj, name, default)
fn visit_getattr(args []string) (string, bool) {
	if args.len >= 2 {
		// Strip quotes from attribute name if it's a string literal
		attr := args[1].trim('\'"')
		if args.len >= 3 {
			return '${args[0]}.${attr} or { ${args[2]} }', true
		}
		return '${args[0]}.${attr}', true
	}
	return '', false
}

// Handle setattr(obj, name, value)
fn visit_setattr(args []string) (string, bool) {
	if args.len >= 3 {
		attr := args[1].trim('\'"')
		return '${args[0]}.${attr} = ${args[2]}', true
	}
	return '', false
}

// Handle hasattr(obj, name)
fn visit_hasattr(args []string) (string, bool) {
	if args.len >= 2 {
		attr := args[1].trim('\'"')
		// V structs always have their fields; use compile-time check approximation
		return '(typeof(${args[0]}.${attr}).name != "")', true
	}
	return '', false
}

// Handle isinstance() call
fn visit_isinstance(args []string) (string, bool) {
	types_arg := args[1]
	// Handle tuple of types: isinstance(x, (A, B)) → x is A || x is B
	// visit_tuple renders Python tuples as V arrays: [A, B, ...]
	if types_arg.starts_with('[') && types_arg.ends_with(']') {
		inner := types_arg[1..types_arg.len - 1]
		types := inner.split(', ')
		if types.len > 1 {
			mut parts := []string{}
			for typ in types {
				parts << '${args[0]} is ${typ}'
			}
			return '(${parts.join(' || ')})', true
		}
		// Single-element tuple: isinstance(x, (A,)) → x is A
		return '${args[0]} is ${types[0]}', true
	}
	// V `is` checks the static (sum-type) variant; inherited types need
	// manual adaptation if the hierarchy is not a V sum type.
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
	// Return the rune expression itself; do not call .str()
	return 'rune(${args[0]})', true
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

// Handle logging.X() calls
fn visit_logging(level string, args []string) (string, bool) {
	if args.len == 0 {
		return '', false
	}
	v_level := match level {
		'warning' { 'warn' }
		'critical', 'exception' { 'error' }
		else { level }
	}

	return 'log.${v_level}(${args[0]})', true
}

// DispatchResult holds the result of a dispatch
struct DispatchResult {
	code    string
	handled bool
	using   string
}

// dispatch_builtin dispatches builtins to their special-case handlers.
pub fn dispatch_builtin(mut t VTranspiler, fname string, node Call, args []string) (string, bool) {
	result := dispatch_builtin_impl(mut t, fname, node, args)
	if result.handled && result.using != '' {
		t.add_using(result.using)
	}
	return result.code, result.handled
}

fn dispatch_builtin_impl(mut t VTranspiler, fname string, node Call, args []string) DispatchResult {
	match fname {
		'range' {
			code, handled := visit_range(args)
			return DispatchResult{code, handled, ''}
		}
		'print' {
			code, handled := visit_print(mut t, node, args)
			return DispatchResult{code, handled, ''}
		}
		'bool' {
			code, handled := visit_bool(mut t, node, args)
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
			// Construct typed closure when first arg is a Lambda AST node
			if node.args.len > 0 {
				first := node.args[0]
				if first is Lambda {
					lam := first as Lambda
					iter_expr := if node.args.len > 1 { node.args[1] } else { Expr(Constant{
							value: NoneValue{}
						}) }
					closure := build_typed_lambda_closure(mut t, lam, iter_expr)
					iter_code := args[1]
					return DispatchResult{'${iter_code}.map(${closure})', true, ''}
				}
			}
			code, handled := visit_map_builtin(args)
			return DispatchResult{code, handled, ''}
		}
		'filter' {
			if node.args.len > 0 {
				first := node.args[0]
				if first is Lambda {
					lam := first as Lambda
					iter_expr := if node.args.len > 1 { node.args[1] } else { Expr(Constant{
							value: NoneValue{}
						}) }
					closure := build_typed_lambda_closure(mut t, lam, iter_expr)
					iter_code := args[1]
					return DispatchResult{'${iter_code}.filter(${closure})', true, ''}
				}
			}
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
			return DispatchResult{code, handled, 'arrays'}
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
		'getattr' {
			code, handled := visit_getattr(args)
			return DispatchResult{code, handled, ''}
		}
		'setattr' {
			code, handled := visit_setattr(args)
			return DispatchResult{code, handled, ''}
		}
		'hasattr' {
			code, handled := visit_hasattr(args)
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
		'logging.debug', 'logging.info', 'logging.warning', 'logging.warn', 'logging.error',
		'logging.critical', 'logging.exception' {
			level := fname.all_after('logging.')
			code, handled := visit_logging(level, args)
			return DispatchResult{code, handled, 'log'}
		}
		'logging.basicConfig', 'logging.getLogger' {
			return DispatchResult{'', true, ''}
		}
		// Path constructor — treat Path objects as plain strings in V.
		'Path' {
			t.add_using('os')
			if args.len > 0 {
				return DispatchResult{args[0], true, 'os'}
			}
			return DispatchResult{"''", true, 'os'}
		}
		else {
			return DispatchResult{'', false, ''}
		}
	}
}

// dispatch_path_method translates pathlib.Path method calls to os.* equivalents.
// Path objects are represented as plain strings in V; os module must be imported.
// Returns (translated_code, true) when matched, ('', false) otherwise.
pub fn dispatch_path_method(mut t VTranspiler, obj string, method string, args []string) (string, bool) {
	// Unique pathlib-only methods always translate; others require obj to be a known path var.
	unique_path_methods := ['read_text', 'read_bytes', 'write_text', 'write_bytes', 'iterdir',
		'glob', 'resolve', 'absolute']
	is_path_var := t.path_vars[obj] or { false }
	if !is_path_var && method !in unique_path_methods {
		return '', false
	}
	match method {
		'read_text' {
			t.add_using('os')
			return "os.read_file(${obj}) or { '' }", true
		}
		'read_bytes' {
			t.add_using('os')
			return 'os.read_bytes(${obj}) or { []u8{} }', true
		}
		'write_text' {
			t.add_using('os')
			text := if args.len > 0 { args[0] } else { "''" }
			return 'os.write_file(${obj}, ${text})!', true
		}
		'write_bytes' {
			t.add_using('os')
			data := if args.len > 0 { args[0] } else { '[]u8{}' }
			return 'os.write_file_array(${obj}, ${data})!', true
		}
		'exists' {
			t.add_using('os')
			return 'os.exists(${obj})', true
		}
		'is_file' {
			t.add_using('os')
			return 'os.is_file(${obj})', true
		}
		'is_dir' {
			t.add_using('os')
			return 'os.is_dir(${obj})', true
		}
		'mkdir' {
			t.add_using('os')
			// parents/exist_ok keyword args ignored; os.mkdir_all handles both
			return 'os.mkdir_all(${obj})!', true
		}
		'rmdir' {
			t.add_using('os')
			return 'os.rmdir(${obj})!', true
		}
		'unlink' {
			t.add_using('os')
			return 'os.rm(${obj})!', true
		}
		'rename' {
			t.add_using('os')
			dst := if args.len > 0 { args[0] } else { "''" }
			return 'os.rename(${obj}, ${dst})!', true
		}
		'iterdir' {
			t.add_using('os')
			return 'os.ls(${obj}) or { [] }', true
		}
		'glob' {
			t.add_using('os')
			pattern := if args.len > 0 { args[0] } else { "'*'" }
			return 'os.glob(os.join_path(${obj}, ${pattern})) or { [] }', true
		}
		'stat' {
			t.add_using('os')
			return 'os.stat(${obj})!', true
		}
		'resolve', 'absolute' {
			t.add_using('os')
			return 'os.abs_path(${obj})', true
		}
		'open' {
			t.add_using('os')
			mode := if args.len > 0 { args[0] } else { "'r'" }
			return 'os.open_file(${obj}, ${mode}, 0o644)!', true
		}
		else {
			return '', false
		}
	}
}

// dispatch_re_func translates Python `re` module function calls to V `regex` equivalents.
// V regex works via RE struct objects, so simple one-liner Python calls are lowered to
// inline compile+call chains using `regex.regex_opt(pattern)!`.
pub fn dispatch_re_func(mut t VTranspiler, fname string, args []string) (string, bool) {
	if !fname.starts_with('re.') {
		return '', false
	}
	t.add_using('regex')
	fn_name := fname[3..] // strip 're.'
	match fn_name {
		'compile' {
			if args.len > 0 {
				return 'regex.regex_opt(${args[0]}) or { panic(err) }', true
			}
			return '', false
		}
		'match', 'fullmatch' {
			// re.match(pattern, string) — anchors at start
			if args.len >= 2 {
				anchor := if fn_name == 'fullmatch' { 'true' } else { 'false' }
				_ = anchor
				return '(regex.regex_opt(${args[0]}) or { panic(err) }).match_string(${args[1]})', true
			}
			return '', false
		}
		'search' {
			// re.search(pattern, string) → find first match position
			if args.len >= 2 {
				return '(regex.regex_opt(${args[0]}) or { panic(err) }).find(${args[1]})', true
			}
			return '', false
		}
		'findall' {
			// re.findall(pattern, string) → []string of all matches
			if args.len >= 2 {
				return '(regex.regex_opt(${args[0]}) or { panic(err) }).find_all_str(${args[1]})', true
			}
			return '', false
		}
		'sub' {
			// re.sub(pattern, repl, string) → replace all occurrences
			if args.len >= 3 {
				return '(regex.regex_opt(${args[0]}) or { panic(err) }).replace(${args[2]}, ${args[1]})', true
			}
			return '', false
		}
		'subn' {
			// re.subn(pattern, repl, string) → (new_string, count) — emit as comment + sub
			if args.len >= 3 {
				return '(regex.regex_opt(${args[0]}) or { panic(err) }).replace(${args[2]}, ${args[1]}) /* subn: count not available */', true
			}
			return '', false
		}
		'split' {
			// re.split(pattern, string) → []string
			if args.len >= 2 {
				return '(regex.regex_opt(${args[0]}) or { panic(err) }).split(${args[1]})', true
			}
			return '', false
		}
		'escape' {
			// re.escape(string) — no direct V equivalent; emit as-is with comment
			if args.len > 0 {
				return '${args[0]} /* re.escape: manual escaping may be needed */', true
			}
			return '', false
		}
		else {
			return '', false
		}
	}
}

// dispatch_itertools_func translates Python `itertools` function calls to V equivalents.
pub fn dispatch_itertools_func(mut t VTranspiler, fname string, args []string) (string, bool) {
	if !fname.starts_with('itertools.') {
		return '', false
	}
	fn_name := fname[10..] // strip 'itertools.'
	match fn_name {
		'chain' {
			// itertools.chain(a, b, c) → flatten [[a...], [b...], [c...]]
			t.add_using('arrays')
			if args.len == 0 {
				return '[]', true
			}
			return 'arrays.flatten([${args.join(', ')}])', true
		}
		'chain.from_iterable' {
			// itertools.chain.from_iterable(it) → arrays.flatten(it)
			t.add_using('arrays')
			if args.len > 0 {
				return 'arrays.flatten(${args[0]})', true
			}
			return '', false
		}
		'islice' {
			// itertools.islice(it, stop) or islice(it, start, stop)
			if args.len == 2 {
				return '${args[0]}[..${args[1]}]', true
			}
			if args.len >= 3 {
				return '${args[0]}[${args[1]}..${args[2]}]', true
			}
			return '', false
		}
		'repeat' {
			// itertools.repeat(x, n) → []T{len: n, init: x}
			t.generated_code_has_any_type = true
			if args.len >= 2 {
				return '[]Any{len: ${args[1]}, init: ${args[0]}} /* itertools.repeat */', true
			}
			if args.len == 1 {
				return '[]Any{} /* itertools.repeat(${args[0]}): infinite repeat, manual loop required */', true
			}
			return '', false
		}
		'count' {
			// itertools.count(start, step) — no direct V equivalent
			if args.len >= 1 {
				return '${args[0]} /* itertools.count: use a manual counter loop */', true
			}
			return '', false
		}
		'zip_longest' {
			// itertools.zip_longest(*its) — no direct equivalent
			t.add_using('arrays')
			t.generated_code_has_any_type = true
			return '[][]Any{} /* itertools.zip_longest: use arrays.group or manual padding loop */', true
		}
		'product' {
			// itertools.product(a, b) — nested loops; emit stub
			t.generated_code_has_any_type = true
			return '[][]Any{} /* itertools.product(${args.join(', ')}): use nested for loops */', true
		}
		'combinations', 'combinations_with_replacement' {
			t.generated_code_has_any_type = true
			return '[][]Any{} /* itertools.${fn_name}(${args.join(', ')}): no direct V equivalent */', true
		}
		'permutations' {
			t.generated_code_has_any_type = true
			return '[][]Any{} /* itertools.permutations(${args.join(', ')}): no direct V equivalent */', true
		}
		'groupby' {
			t.generated_code_has_any_type = true
			return '[][]Any{} /* itertools.groupby(${args.join(', ')}): no direct V equivalent */', true
		}
		'takewhile' {
			if args.len >= 2 {
				return '${args[1]}.filter(${args[0]})', true
			}
			return '', false
		}
		'dropwhile' {
			t.generated_code_has_any_type = true
			return '[]Any{} /* itertools.dropwhile(${args.join(', ')}): no direct V equivalent */', true
		}
		'starmap' {
			t.generated_code_has_any_type = true
			return '[]Any{} /* itertools.starmap(${args.join(', ')}): use .map() with destructuring */', true
		}
		'accumulate' {
			t.generated_code_has_any_type = true
			return '[]Any{} /* itertools.accumulate(${args.join(', ')}): use a manual accumulate loop */', true
		}
		'flatten' {
			t.add_using('arrays')
			if args.len > 0 {
				return 'arrays.flatten(${args[0]})', true
			}
			return '', false
		}
		else {
			return '', false
		}
	}
}

// dispatch_attr handles attribute accesses like sys.argv.
pub fn dispatch_attr(mut t VTranspiler, attr_path string) (string, bool) {
	match attr_path {
		'sys.argv' {
			t.add_using('os')
			return 'os.args', true
		}
		else {
			// Path property attributes — only translate when the object is a known
			// pathlib.Path variable tracked in t.path_vars.
			parts := attr_path.split('.')
			if parts.len >= 2 {
				obj := parts[..parts.len - 1].join('.')
				prop := parts[parts.len - 1]
				// Only translate path properties for known path variables
				if t.path_vars[obj] or { false } {
					match prop {
						'name' {
							t.add_using('os')
							return 'os.file_name(${obj})', true
						}
						'stem' {
							t.add_using('os')
							return 'os.file_name(${obj}).all_before_last(".")', true
						}
						'suffix' {
							t.add_using('os')
							return '"." + os.file_ext(${obj})', true
						}
						'parent' {
							t.add_using('os')
							return 'os.dir(${obj})', true
						}
						else {}
					}
				}
			}
			return '', false
		}
	}
}

// Get V annotation from an expression
fn get_v_annotation(expr Expr) string {
	match expr {
		Attribute { return expr.v_annotation or { '' } }
		BinOp { return expr.v_annotation or { '' } }
		BoolOp { return expr.v_annotation or { '' } }
		Call { return expr.v_annotation or { '' } }
		Compare { return expr.v_annotation or { '' } }
		Constant { return expr.v_annotation or { '' } }
		Dict { return expr.v_annotation or { '' } }
		List { return expr.v_annotation or { '' } }
		Name { return expr.v_annotation or { '' } }
		Set { return expr.v_annotation or { '' } }
		Subscript { return expr.v_annotation or { '' } }
		Tuple { return expr.v_annotation or { '' } }
		UnaryOp { return expr.v_annotation or { '' } }
		else { return '' }
	}
}
