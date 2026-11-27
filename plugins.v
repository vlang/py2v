module main

// Dispatch table for built-in functions that need special handling
// Returns (result, handled) - if handled is false, fall back to default call handling

// Handle range() call
// Note: range expressions like `0..n` only work in for loops, not as expressions
// When used as an expression, we return an array initializer
fn visit_range(mut t VTranspiler, node Call, args []string) (string, bool) {
	if args.len !in [1, 2, 3] || args.len != node.args.len || node.keywords.len > 0 {
		return '', false
	}
	if args.len == 3 && is_literal_zero_range_step(node.args[2]) {
		return t.unsupported_site('range_zero_step', 'range() step must not be zero', ''), true
	}
	if node.args.any(it is Starred) {
		if args.len == 1 && node.args[0] is Starred {
			operand := (node.args[0] as Starred).value
			if !t.infer_expr_type(operand).starts_with('(') {
				t.runtime_helper('range_bound')
				t.runtime_helper('range_array')
				unpack := t.runtime_helper('range_unpack')
				return '${unpack}(${args[0].trim_string_left('...')})', true
			}
		}
		return t.unsupported_site('range_unpack', 'range needs one unpacked native array', ''), true
	}
	if args.len == 1 {
		if _ := literal_word(node.args[0]) {
			return '[]int{len: ${args[0]}, init: index}', true
		}
	}
	if args.len == 2 {
		if start := literal_word(node.args[0]) {
			if stop := literal_word(node.args[1]) {
				if stop >= start {
					return '[]int{len: ${args[1]} - ${args[0]}, init: index + ${args[0]}}', true
				}
			}
		}
	}
	convert := t.runtime_helper('range_bound')
	mut bounds := []string{cap: 3}
	if args.len == 1 {
		bounds << '0'
	}
	bounds << args.map('${convert}(${it})')
	if args.len < 3 {
		bounds << '1'
	}
	return '${t.runtime_helper('range_array')}(${bounds.join(', ')})', true
}

// Handle print() call
fn visit_print(mut t VTranspiler, node Call, args []string) (string, bool) {
	// `sep` and `end` are honored when they are string constants: each is kept as the V
	// literal of its text. Any other value (and `file`, `flush`) leaves the defaults.
	mut sep := "' '"
	mut end := ''
	mut newline := true
	for kw in node.keywords {
		name := kw.arg or { continue }
		if name !in ['sep', 'end'] || kw.value !is Constant {
			continue
		}
		value := (kw.value as Constant).value
		if value is string {
			if name == 'sep' {
				sep = t.visit_expr(kw.value)
			} else {
				newline = value == '\n'
				end = t.visit_expr(kw.value)
			}
		}
	}
	if node.args.len == 0 {
		return if newline { "println('')" } else { 'print(${end})' }, true
	}
	// A separator literal in double quotes holds a single quote and is never pasted.
	sep_text := if sep.len >= 2 && sep.starts_with("'") { sep[1..sep.len - 1] } else { '' }
	sep_pastes := sep.starts_with("'")

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
					continue
				}
				// A literal emitted with double quotes holds a single quote; it cannot
				// be pasted between single quotes, so the general path prints it.
			}
		}
		all_string_literals = false
		break
	}

	if all_string_literals && string_parts.len > 0 && sep_pastes {
		// Combine string literals with the separator
		joined := "'${string_parts.join(sep_text)}'"
		return print_with_end(joined, true, newline, end), true
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
			if c.value is NoneValue {
				parts << "'None'"
				continue
			}
			if c.value is string {
				// Keep the processed string literal for the final print expression.
				parts << arg_str_proc
				continue
			}
			// Bool constants need Python-style True/False
			if c.value is bool {
				parts << bool_to_python_str(arg_str_proc)
				continue
			}
			// Keep constants for conversion when joining multiple arguments below.
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
		if text := t.native_scalar_text(arg, arg_str) {
			parts << text
			continue
		}
		// Names holding boxed tuple lists need Python repr just like direct comprehensions.
		if arg is Name && t.var_types[(arg as Name).id] == '[]pyrt.Value' {
			t.add_using('pyrt')
			parts << 'pyrt.str(pyrt.box(${arg_str}))'
			continue
		}
		// A tuple-valued map comprehension retains Python tuple identity in Value.
		// Print the containing list with Python's nested repr, not V's debug format.
		if arg is ListComp && (arg as ListComp).elt is Tuple
			&& arg_str.contains('pyrt.new_tuple(') {
			t.add_using('pyrt')
			parts << 'pyrt.str(pyrt.box(${arg_str}))'
			continue
		}
		// Native maps with runtime values need Python's recursive representation.
		if inferred.starts_with('map[') && (inferred.ends_with(']Any')
			|| inferred.ends_with(']pyrt.Value')) {
			t.add_using('pyrt')
			parts << 'pyrt.str(pyrt.box(${arg_str}))'
			continue
		}

		// Keep other expressions for the final print expression below.
		parts << arg_str
	}

	// Build final println with any trailing comments collected from .format fallbacks
	mut println_code := ''
	if parts.len == 1 {
		is_text := node.args[0] is Constant && (node.args[0] as Constant).value is string
		println_code = print_with_end(parts[0], is_text, newline, end)
	} else if joined := interpolated_print(node, parts, sep_text, sep_pastes) {
		// one string with each value interpolated: `println('hello ${name}')`
		println_code = print_with_end(joined, true, newline, end)
	} else {
		// Leave unsupported starred expansion unconverted.
		for i, part in parts {
			if node.args[i] !is Starred {
				parts[i] = '(${part}).str()'
			}
		}
		glue := if sep == "''" { ' + ' } else { ' + ${sep} + ' }
		println_code = print_with_end(parts.join(glue), true, newline, end)
	}
	if trailing_comments.len > 0 {
		println_code = '${println_code} ${trailing_comments.join(' ')}'
	}
	return println_code, true
}

// interpolated_print joins the parts of a `print` into one V string literal, the text of
// each string constant pasted and every other value as `${value}`, which prints what
// `.str()` gives. It declines (none) when a part cannot stand inside a literal: code that
// holds a quote or spans lines, a constant with a `$`, a quote or a backslash, a starred
// argument, or a separator that is not a plain single-quoted text.
fn interpolated_print(node Call, parts []string, sep_text string, sep_pastes bool) ?string {
	if !sep_pastes || sep_text.contains_any('$\\') {
		return none
	}
	mut pieces := []string{}
	for i, part in parts {
		arg := node.args[i]
		if arg is Starred {
			return none
		}
		is_text := arg is Constant && (arg as Constant).value is string
		if is_text {
			if part.len < 2 || !part.starts_with("'") || !part.ends_with("'") {
				return none
			}
			inner := part[1..part.len - 1]
			if inner.contains_any("$\\'") {
				return none
			}
			pieces << inner
			continue
		}
		if part.contains_any('\'"\n{}') {
			return none
		}
		pieces << '\${' + part + '}'
	}
	return "'" + pieces.join(sep_text) + "'"
}

// print_with_end emits the call that prints `code`: `println` when the line ends with a
// newline, else `print` with the V literal `end` appended (nothing for an empty one).
// `is_text` says `code` is already a string; any other value is converted before `+`.
fn print_with_end(code string, is_text bool, newline bool, end string) string {
	if newline {
		return 'println(${code})'
	}
	if end == "''" {
		return 'print(${code})'
	}
	text := if is_text { code } else { '(${code}).str()' }
	return 'print(${text} + ${end})'
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
			return '(${as_receiver(args[0])}.len > 0)', true
		}
		// Use infer_expr_type as fallback
		inferred := t.infer_expr_type(node.args[0])
		if inferred in ['int', 'i64', 'f64', 'i8', 'i16', 'u8', 'u16', 'u32', 'u64'] {
			return '(${args[0]} != 0)', true
		}
		if inferred == 'string' {
			return '(${as_receiver(args[0])}.len > 0)', true
		}
	}
	return '(${args[0]} != 0)', true // Default to numeric comparison
}

// Handle int() call
fn visit_int(mut t VTranspiler, node Call, args []string) (string, bool) {
	if args.len == 0 {
		return '0', true
	}
	typ := t.infer_expr_type(node.args[0])
	if typ == 'string' {
		return t.parse_native_integer(node, args[0], '10'), true
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
				return '${as_receiver(args[0])}.f64()', true
			}
		}
		ann := get_v_annotation(node.args[0])
		if ann == 'string' {
			return '${as_receiver(args[0])}.f64()', true
		}
	}
	return 'f64(${args[0]})', true
}

// Handle str() call
fn visit_str(mut t VTranspiler, node Call, args []string) (string, bool) {
	if args.len == 0 {
		return "''", true
	}
	arg := args[0]
	if text := t.native_scalar_text(node.args[0], arg) {
		return text, true
	}
	// A string literal is its own text; anything else is converted, which V's
	// `.str()` also accepts on a string.
	if arg.len > 1 && arg[0] in [`'`, `"`] && arg[arg.len - 1] == arg[0] {
		return arg, true
	}
	if arg.len > 0 && is_simple_identifier(arg) {
		return '${arg}.str()', true
	}
	return '(${arg}).str()', true
}

// native_scalar_text converts V values whose default text differs from Python's.
fn (mut t VTranspiler) native_scalar_text(expr Expr, code string) ?string {
	typ := t.infer_expr_type(expr)
	if typ == 'bool' {
		return '${t.runtime_helper('bool_text')}(${code})'
	}
	if typ in ['f32', 'f64', 'float'] {
		t.add_using('strconv')
		return '${t.runtime_helper('float_text')}(${code})'
	}
	if get_expr_annotation(expr) == 'bytes' || (expr is Constant && expr.value is BytesValue) {
		t.add_using('strings')
		return '${t.runtime_helper('bytes_text')}(${code})'
	}
	if get_expr_annotation(expr) in ['tuple[int, ...]', 'tuple[int, Ellipsis]'] {
		return '${t.runtime_helper('int_tuple_text')}(${code})'
	}
	return none
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
	return '${as_receiver(args[0])}.len', true
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

// Handle pow() call
fn visit_pow(mut t VTranspiler, node Call, args []string) (string, bool, string) {
	if args.len != 2 { return '', false, '' }
	if is_zero_numeric_literal(node.args[0]) && is_negative_numeric_literal(node.args[1]) {
		return t.unsupported_site('negative_zero_power', 'zero to a negative power raises a catchable Python ZeroDivisionError', ''), true, ''
	}
	if code := t.native_integer_binary('Pow', node.args[0], node.args[1], args[0], args[1],
		node.loc, false) {
		return code, true, ''
	}
	return 'math.pow(${args[0]}, ${args[1]})', true, 'math'
}

// Numeric literal provenance is needed because native []f64 can contain Python integers.
// A Python annotation alone never converts a value.
fn python_numeric_literal_kind(t &VTranspiler, expr Expr) string {
	return match expr {
		Constant {
			if expr.value is f64 {
				'float'
			} else if expr.value is int || expr.value is i64 || expr.value is u64
				|| expr.value is bool {
				'int'
			} else {
				'unknown'
			}
		}
		UnaryOp {
			if expr.op is UAdd || expr.op is USub {
				python_numeric_literal_kind(t, *expr.operand)
			} else {
				'unknown'
			}
		}
		Call {
			if expr.func is Name && expr.func.id == 'float'
				&& 'float' !in t.module_functions && !t.is_bound_in_scope('float')
				&& expr.args.len == 1 && expr.keywords.len == 0 {
				'float'
			} else {
				'unknown'
			}
		}
		else { 'unknown' }
	}
}

fn python_numeric_list_kind(t &VTranspiler, items List) string {
	if items.elts.len == 0 { return 'empty' }
	mut has_int := false
	mut has_float := false
	for item in items.elts {
		kind := python_number_kind(t, item, t.sum_list_kinds)
		if kind == 'unknown' { return 'unknown' }
		if kind == 'float' { has_float = true }
		if kind == 'int' { has_int = true }
	}
	return if has_int && has_float {
		'mixed'
	} else if has_float {
		'float'
	} else {
		'int'
	}
}

// A native float type may have been assigned after a Python int-to-float coercion.
fn python_number_kind(t &VTranspiler, expr Expr, bindings map[string]string) string {
	literal := python_numeric_literal_kind(t, expr)
	if literal != 'unknown' { return literal }
	match expr {
		Name {
			return match bindings[expr.id] {
				'float_value' { 'float' }
				'int_value' { 'int' }
				else { 'unknown' }
			}
		}
		UnaryOp {
			if expr.op is UAdd || expr.op is USub {
				return python_number_kind(t, *expr.operand, bindings)
			}
		}
		BinOp {
			if expr.op is Div { return 'float' }
			a := python_number_kind(t, *expr.left, bindings)
			b := python_number_kind(t, *expr.right, bindings)
			if expr.op is Pow {
				if a == 'float' && (b == 'int' || get_expr_annotation(*expr.right) == 'int') {
					return 'float'
				}
			} else if expr.op is Add || expr.op is Sub || expr.op is Mult || expr.op is Mod
				|| expr.op is FloorDiv {
				if a == 'float' || b == 'float' { return 'float' }
				if a == 'int' && b == 'int' { return 'int' }
			}
		}
		Call {
			if expr.func is Name && expr.keywords.len == 0 {
				if expr.func.id == 'abs' && expr.args.len == 1 && 'abs' !in t.module_functions
					&& !t.is_bound_in_scope('abs') {
					return python_number_kind(t, expr.args[0], bindings)
				}
				if t.sum_float_results[expr.func.id] && !t.is_bound_in_scope(expr.func.id) {
					return 'float'
				}
			}
		}
		Subscript {
			if expr.slice !is Slice && (get_expr_annotation(expr) == 'py2v_float_element'
				|| (expr.value is Name && bindings[expr.value.id] in ['float', 'maybe_float'])) {
				return 'float'
			}
		}
		IfExp {
			a := python_number_kind(t, *expr.body, bindings)
			if a == python_number_kind(t, *expr.orelse, bindings) { return a }
		}
		else {}
	}
	return 'unknown'
}

fn python_sum_iter_kinds(t &VTranspiler, iter Expr) []string {
	if iter is Call && iter.func is Name && iter.func.id !in t.module_functions
		&& !t.is_bound_in_scope(iter.func.id) && iter.keywords.len == 0 {
		if iter.func.id == 'range' { return ['int'] }
		if iter.func.id == 'enumerate' && iter.args.len in [1, 2] {
			return ['int', python_numeric_arg_list_kind(t, iter.args[0])]
		}
		if iter.func.id == 'zip' {
			return iter.args.map(python_numeric_arg_list_kind(t, it))
		}
	}
	return [python_numeric_arg_list_kind(t, iter)]
}

fn python_float_comprehension_kind(t &VTranspiler, elt Expr, generators []Comprehension) string {
	if generators.len != 1 { return 'unknown' }
	gen := generators[0]
	mut bindings := t.sum_list_kinds.clone()
	kinds := python_sum_iter_kinds(t, gen.iter)
	for i, name in for_target_names(gen.target) {
		bindings[name] = match kinds[i] or { 'unknown' } {
			'float', 'maybe_float' { 'float_value' }
			'int' { 'int_value' }
			else { 'unknown' }
		}
	}
	if python_number_kind(t, elt, bindings) != 'float' { return 'unknown' }
	if gen.ifs.len == 0 {
		if gen.iter is List {
			return if gen.iter.elts.len == 0 { 'empty' } else { 'float' }
		}
		if gen.iter is Name && t.sum_list_kinds[gen.iter.id] == 'empty' { return 'empty' }
		if nonempty := python_sum_range_nonempty(t, gen.iter) {
			return if nonempty { 'float' } else { 'empty' }
		}
		if python_sum_iter_nonempty(t, gen.iter) { return 'float' }
	}
	return 'maybe_float'
}

fn python_sum_range_nonempty(t &VTranspiler, iter Expr) ?bool {
	if iter !is Call { return none }
	if iter.func !is Name || iter.func.id != 'range' || 'range' in t.module_functions
		|| t.is_bound_in_scope('range') || iter.keywords.len != 0 {
		return none
	}
	if iter.args.len == 1 {
		stop := literal_signed_integer(iter.args[0]) or { return none }
		return stop > 0
	}
	if iter.args.len !in [2, 3] { return none }
	start := literal_signed_integer(iter.args[0]) or { return none }
	stop := literal_signed_integer(iter.args[1]) or { return none }
	step := if iter.args.len == 3 {
		literal_signed_integer(iter.args[2]) or { return none }
	} else {
		i64(1)
	}
	if step == 0 { return none }
	return if step > 0 { start < stop } else { start > stop }
}

fn python_sum_iter_nonempty(t &VTranspiler, iter Expr) bool {
	return match iter {
		List { iter.elts.len > 0 }
		Tuple { iter.elts.len > 0 }
		Name {
			get_expr_annotation(iter) == 'py2v_nonempty_list'
				|| t.sum_list_kinds[iter.id] in ['float', 'int', 'mixed', 'nonempty']
		}
		Call {
			if iter.func is Name && iter.func.id !in t.module_functions
				&& !t.is_bound_in_scope(iter.func.id) && iter.keywords.len == 0
				&& iter.args.len > 0 {
				if iter.func.id == 'enumerate' {
					python_sum_iter_nonempty(t, iter.args[0])
				} else if iter.func.id == 'zip' {
					iter.args.all(python_sum_iter_nonempty(t, it))
				} else {
					false
				}
			} else {
				false
			}
		}
		else { false }
	}
}

fn python_numeric_arg_list_kind(t &VTranspiler, expr Expr) string {
	return match expr {
		List { python_numeric_list_kind(t, expr) }
		Tuple { python_numeric_list_kind(t, List{ elts: expr.elts }) }
		Name {
			kind := t.sum_list_kinds[expr.id]
			if get_expr_annotation(expr) == 'py2v_bound_generator' {
				'one_shot_generator'
			} else if kind in ['float', 'maybe_float', 'empty'] {
				kind
			} else if get_expr_annotation(expr) == 'py2v_float_list' {
				'maybe_float'
			} else if kind in ['float_buffer', 'maybe_float_buffer'] {
				if get_expr_annotation(expr) == 'py2v_float_comprehension' {
					kind.all_before('_buffer')
				} else {
					'unknown'
				}
			} else {
				kind
			}
		}
		BinOp {
			if expr.op is Mult {
				left := python_numeric_arg_list_kind(t, *expr.left)
				base, source, count := if left in ['float', 'maybe_float', 'empty'] {
					left, *expr.left, *expr.right
				} else {
					python_numeric_arg_list_kind(t, *expr.right), *expr.right, *expr.left
				}
				if base in ['float', 'maybe_float', 'empty'] {
					if size := literal_signed_integer(count) {
						if size > 0 { return base }
						if source is Name || (source is List && source.elts.all(it is Constant)) {
							return 'empty'
						}
					}
					return if base == 'empty' { 'unknown' } else { 'maybe_float' }
				}
			}
			'unknown'
		}
		Subscript {
			if expr.slice is Slice && expr.value is Name {
				match t.sum_list_kinds[expr.value.id] {
					'float', 'maybe_float' { 'maybe_float' }
					'int' { 'int' }
					else { 'unknown' }
				}
			} else if expr.value is Name && t.sum_list_kinds[expr.value.id] == 'float_lists' {
				'maybe_float'
			} else {
				'unknown'
			}
		}
		GeneratorExp { python_float_comprehension_kind(t, expr.elt, expr.generators) }
		ListComp { python_float_comprehension_kind(t, expr.elt, expr.generators) }
		Call {
			if expr.func is Name && expr.func.id == 'sorted' && 'sorted' !in t.module_functions
				&& !t.is_bound_in_scope('sorted') && expr.args.len == 1 && expr.keywords.len == 0 {
				kind := python_numeric_arg_list_kind(t, expr.args[0])
				if kind in ['float', 'maybe_float', 'int'] { kind } else { 'unknown' }
			} else if expr.func is Name && t.sum_uniform_array_results[expr.func.id]
				&& !t.is_bound_in_scope(expr.func.id) {
				'uniform_sum_array'
			} else {
				'unknown'
			}
		}
		else { 'unknown' }
	}
}

// The frontend can materialize a comprehension as an empty local and one
// append loop. Only the generated use carries the matching provenance marker.
fn materialized_float_sum_kind(t &VTranspiler, declaration Stmt, statement Stmt) ?(string, string) {
	if declaration !is AnnAssign || statement !is For { return none }
	decl := declaration as AnnAssign
	loop := statement as For
	value := decl.value or { return none }
	initial := *value
	target := *decl.target
	if initial !is List || target !is Name { return none }
	if (initial as List).elts.len != 0 || loop.body.len != 1 || loop.orelse.len > 0 { return none }
	name := (target as Name).id
	mut append := loop.body[0]
	mut filters := []Expr{}
	if append is If && append.body.len == 1 && append.orelse.len == 0 {
		filters << *append.test
		append = append.body[0]
	}
	if append !is ExprStmt { return none }
	expr := *(append as ExprStmt).value
	if expr !is Call { return none }
	call := expr as Call
	func := *call.func
	if func !is Attribute || call.args.len != 1 || call.keywords.len != 0 { return none }
	method := func as Attribute
	receiver := *method.value
	if receiver !is Name { return none }
	if method.attr != 'append' || (receiver as Name).id != name { return none }
	kind := python_float_comprehension_kind(t, call.args[0], [Comprehension{
		target: loop.target
		iter:   loop.iter
		ifs:    filters
	}])
	if kind !in ['float', 'maybe_float'] { return none }
	return name, '${kind}_buffer'
}

fn python_float_return(t &VTranspiler, body []Stmt) bool {
	mut bindings := map[string]string{}
	for stmt in body {
		match stmt {
			ExprStmt {
				if stmt.value !is Constant { return false }
			}
			Assign {
				if stmt.targets.len != 1 || stmt.targets[0] !is Name { return false }
				target := stmt.targets[0] as Name
				kind := python_number_kind(t, *stmt.value, bindings)
				bindings[target.id] = '${kind}_value'
			}
			Return {
				value := stmt.value or { return false }
				return python_number_kind(t, *value, bindings) == 'float'
			}
			else { return false }
		}
	}
	return false
}

fn sorted_sum_inputs(body []Stmt, bindings map[string]int, calls []BindingCall) map[string]bool {
	mut sources := map[string]string{}
	for stmt in body {
		if stmt !is Assign { continue }
		assignment := stmt as Assign
		if assignment.targets.len != 1 || assignment.targets[0] !is Name { continue }
		target := assignment.targets[0] as Name
		value := *assignment.value
		if bindings[target.id] != 1 || target.is_mutable || value !is Call { continue }
		call := value as Call
		if call.func is Name && call.func.id == 'sorted' && call.args.len == 1
			&& call.keywords.len == 0 && call.args[0] is Name {
			sources[target.id] = (call.args[0] as Name).id
		}
	}
	mut result := map[string]bool{}
	for site in calls {
		call := site.call
		if call.func !is Name || call.func.id != 'sum' || call.args.len == 0 { continue }
		arg := call.args[0]
		if arg is Subscript && arg.slice is Slice && arg.value is Name {
			if source := sources[arg.value.id] { result[source] = true }
		}
	}
	return result
}

fn (t &VTranspiler) integer_sorted_sum_calls(def FunctionDef, sites []BindingCall) bool {
	annotation := def.returns or { return false }
	if t.typename_from_annotation(*annotation) != 'bool' || def.args.args.len != 1
		|| def.args.posonlyargs.len != 0 || def.args.defaults.len != 0 {
		return false
	}
	mut found := false
	for site in sites {
		call := site.call
		if call.func !is Name || call.func.id != def.name { continue }
		if call.keywords.len != 0 || call.args.len != 1 || call.args[0] !is List {
			return false
		}
		items := call.args[0] as List
		if items.elts.len == 0 { return false }
		for element in items.elts {
			_ := literal_signed_integer(element) or { return false }
		}
		found = true
	}
	return found
}

fn (mut t VTranspiler) plan_float_sum_sources(stmts []Stmt, uses map[string]int, sites []BindingCall) {
	t.sum_float_results = map[string]bool{}
	t.sum_parameter_kinds = map[string][]string{}
	if t.module_name !in ['', 'main'] || 'sum' in t.module_functions { return }
	mut defs := map[string]FunctionDef{}
	mut calls := map[string][]BindingCall{}
	mut dependencies := map[string]map[string]int{}
	mut sorted_inputs := map[string]map[string]bool{}
	mut direct := map[string]int{}
	for site in sites {
		if site.call.func is Name { direct[site.call.func.id]++ }
	}
	for stmt in stmts {
		if stmt is FunctionDef && stmt.name in t.module_safe_signatures && !stmt.is_class_method
			&& !stmt.is_nested && uses[':load:${stmt.name}'] == direct[stmt.name] {
			defs[stmt.name] = stmt
			mut bindings := map[string]int{}
			mut seen := []BindingCall{}
			count_call_bindings(stmt.body, mut bindings, mut seen, true)
			calls[stmt.name] = seen
			mut buffers := map[string]Stmt{}
			for i, body_stmt in stmt.body {
				if i > 0 && body_stmt is For && stmt.body[i - 1] is AnnAssign {
					decl := stmt.body[i - 1] as AnnAssign
					if decl.target is Name {
						if _, _ := materialized_float_sum_kind(t, stmt.body[i - 1], body_stmt) {
							continue
						}
						buffers[decl.target.id] = body_stmt
					}
				}
			}
			mut reads := {
				':load:': 1
			}
			mut ignored := []BindingCall{}
			if bindings['sum'] == 0 && !stmt.args.args.any(it.arg == 'sum') {
				if uses['sorted'] == 0 && bindings['sorted'] == 0 && 'sorted' !in t.module_functions
					&& !stmt.args.args.any(it.arg == 'sorted') && !stmt.args.posonlyargs.any(it.arg == 'sorted')
					&& !stmt.args.kwonlyargs.any(it.arg == 'sorted') {
					sorted_inputs[stmt.name] = sorted_sum_inputs(stmt.body, bindings, seen)
				}
				for use in seen {
					call := use.call
					if call.func is Name && call.func.id == 'sum' && call.args.len > 0 {
						items := call.args[0]
						if items is Name && get_expr_annotation(items) == 'py2v_float_comprehension' {
							if materialization := buffers[items.id] {
								count_call_bindings(materialization, mut reads, mut ignored, true)
							}
						} else if python_numeric_arg_list_kind(t, items) !in ['float', 'maybe_float',
							'empty', 'int', 'mixed'] {
							count_call_bindings(items, mut reads, mut ignored, true)
						}
					}
				}
			}
			dependencies[stmt.name] = reads
			if bindings['float'] == 0 && bindings['abs'] == 0
				&& !stmt.args.args.any(it.arg in ['float', 'abs']) && python_float_return(t, stmt.body) {
				t.sum_float_results[stmt.name] = true
			}
		}
	}
	for {
		mut changed := false
		for name, def in defs {
			mut reads := dependencies[name].clone()
			mut ignored := []BindingCall{}
			function_calls := calls[name] or { continue }
			for use in function_calls {
				call := use.call
				if call.func is Name {
					for i, kind in t.sum_parameter_kinds[call.func.id] {
						if kind != '' && i < call.args.len {
							count_call_bindings(call.args[i], mut reads, mut ignored, true)
						}
					}
				}
			}
			mut args := def.args.posonlyargs.clone()
			args << def.args.args
			mut kinds := []string{len: args.len}
			for i, arg in args {
				from_sorted := sorted_inputs[name][arg.arg]
				if (reads[':load:${arg.arg}'] == 0 && !from_sorted) || arg.is_mutable
					|| arg.arg in def.mutable_vars {
					continue
				}
				annotation := arg.annotation or { continue }
				kinds[i] = match t.typename_from_annotation(*annotation) {
					'f64' { 'float_value' }
					'[]f64' { 'maybe_float' }
					'[][]f64' { 'float_lists' }
					else { '' }
				}
				if from_sorted && kinds[i] == 'maybe_float' && t.integer_sorted_sum_calls(def, sites) {
					kinds[i] = 'int'
				}
				default_index := i - (args.len - def.args.defaults.len)
				if default_index >= 0 && !python_sum_argument_matches(t, def.args.defaults[default_index], kinds[i]) {
					kinds[i] = ''
				}
			}
			if kinds.any(it != '') && kinds != t.sum_parameter_kinds[name] {
				t.sum_parameter_kinds[name] = kinds
				changed = true
			}
		}
		if !changed { break }
	}
	// Once iterable kinds are available, discard scalar contracts that do not
	// affect the element proof. A float operand already forces float arithmetic.
	for {
		mut changed := false
		for name, def in defs {
			mut kinds := t.sum_parameter_kinds[name].clone()
			if 'float_value' !in kinds { continue }
			function_calls := calls[name] or { continue }
			mut formals := def.args.posonlyargs.clone()
			formals << def.args.args
			for i, kind in kinds {
				if kind != 'float_value' { continue }
				kinds[i] = ''
				if t.sum_calls_remain_proven(def.body, function_calls, formals, kinds) {
					changed = true
				} else {
					kinds[i] = kind
				}
			}
			if kinds.all(it == '') {
				t.sum_parameter_kinds.delete(name)
			} else {
				t.sum_parameter_kinds[name] = kinds
			}
		}
		if !changed { break }
	}
}

fn (mut t VTranspiler) sum_calls_remain_proven(body []Stmt, calls []BindingCall, formals []Arg, kinds []string) bool {
	saved := t.sum_list_kinds.clone()
	defer { t.sum_list_kinds = saved }
	for i, arg in formals {
		t.sum_list_kinds[arg.arg] = kinds[i]
	}
	for i, stmt in body {
		if i > 0 {
			if name, kind := materialized_float_sum_kind(t, body[i - 1], stmt) {
				t.sum_list_kinds[name] = kind
			}
		}
	}
	for site in calls {
		call := site.call
		if call.func !is Name { continue }
		callee := (call.func as Name).id
		if callee == 'sum' && call.args.len > 0 {
			if python_numeric_arg_list_kind(t, call.args[0]) !in ['float', 'maybe_float', 'empty',
				'int'] {
				return false
			}
		} else {
			for i, kind in t.sum_parameter_kinds[callee] {
				if kind != '' && i < call.args.len && !python_sum_argument_matches(t, call.args[i], kind) {
					return false
				}
			}
		}
	}
	return true
}

fn python_sum_argument_matches(t &VTranspiler, expr Expr, expected string) bool {
	return match expected {
		'float_value' { python_number_kind(t, expr, t.sum_list_kinds) == 'float' }
		'maybe_float' { python_numeric_arg_list_kind(t, expr) in ['float', 'maybe_float', 'empty'] }
		'int' { python_numeric_arg_list_kind(t, expr) == 'int' }
		'float_lists' {
			match expr {
				Name { t.sum_list_kinds[expr.id] == 'float_lists' }
				List { expr.elts.all(python_sum_argument_matches(t, it, 'maybe_float')) }
				else { false }
			}
		}
		else { true }
	}
}

fn python_sum_start(call Call) ?Expr {
	if call.args.len == 2 && call.keywords.len == 0 { return call.args[1] }
	if call.args.len == 1 && call.keywords.len == 1 && (call.keywords[0].arg or { '' }) == 'start' {
		return call.keywords[0].value
	}
	return none
}

fn (mut t VTranspiler) sum_may_return_integer_zero(call Call) bool {
	if call.func !is Name || call.func.id != 'sum' || call.args.len == 0
		|| 'sum' in t.module_functions || t.is_bound_in_scope('sum')
		|| python_numeric_arg_list_kind(t, call.args[0]) != 'maybe_float' {
		return false
	}
	if start := python_sum_start(call) {
		return t.division_operand_type(start, t.infer_expr_type(start)) in ['int', 'i64']
	}
	return call.args.len == 1 && call.keywords.len == 0
}

// A local returned array can retain the integer seed alongside float sums.
// Its single initialization and append-only uses give it one representation.
fn (mut t VTranspiler) sum_result_array_binding(body []Stmt, result Expr) string {
	if result !is Name { return '' }
	name := (result as Name).id
	mut uses := {
		':load:': 1
	}
	mut calls := []BindingCall{}
	count_call_bindings(body, mut uses, mut calls, true)
	if uses[name] != 1 { return '' }
	mut initialized := false
	for stmt in body {
		if stmt is Assign && stmt.targets.len == 1 && stmt.targets[0] is Name
			&& stmt.targets[0].id == name && stmt.value is BinOp && stmt.value.op is Mult
			&& stmt.value.left is List && stmt.value.left.elts.len == 1 {
			initialized = true
			break
		}
	}
	if !initialized { return '' }
	mut appends := 0
	for site in calls {
		call := site.call
		if call.func is Attribute && call.func.attr == 'append' && call.func.value is Name
			&& call.func.value.id == name && call.args.len == 1 && call.keywords.len == 0
			&& call.args[0] is Call {
			if t.sum_may_return_integer_zero(call.args[0]) { appends++ }
		}
	}
	return if appends > 0 && uses[':load:${name}'] == appends + 1 { name } else { '' }
}

// With the same width for repetition and a single unfiltered range, the
// returned array contains only floats when there are elements, or one int zero.
fn (t &VTranspiler) sum_result_array_is_uniform(body []Stmt, binding string) bool {
	mut uses := {
		':load:': 1
	}
	mut calls := []BindingCall{}
	count_call_bindings(body, mut uses, mut calls, true)
	if uses[':load:${binding}'] != 2 { return false }
	mut width := ''
	mut append_count := 0
	for stmt in body {
		if stmt is Assign && stmt.targets.len == 1 && stmt.targets[0] is Name
			&& stmt.targets[0].id == binding {
			value := *stmt.value
			if value is BinOp && value.left is List && value.right is Name
				&& value.left.elts.len == 1
				&& value.right.id in t.param_idents && !t.param_idents[value.right.id]
				&& uses[value.right.id] == 0
				&& python_number_kind(t, value.left.elts[0], t.sum_list_kinds) == 'float' {
				width = value.right.id
			}
		}
		if stmt is ExprStmt && stmt.value is Call {
			call := stmt.value as Call
			if call.func is Attribute && call.func.attr == 'append' && call.func.value is Name
				&& call.func.value.id == binding && call.args.len == 1 && call.args[0] is Call {
				sum := call.args[0] as Call
				if width == '' || sum.args.len != 1 || sum.keywords.len != 0 { return false }
				items := sum.args[0]
				if items !is GeneratorExp { return false }
				generators := (items as GeneratorExp).generators
				if generators.len != 1 || generators[0].ifs.len != 0 { return false }
				iter := generators[0].iter
				if iter !is Call { return false }
				range := iter as Call
				if range.func !is Name || range.func.id != 'range' || 'range' in t.module_functions
					|| t.is_bound_in_scope('range') || range.args.len != 1 || range.keywords.len != 0
					|| range.args[0] !is Name || range.args[0].id != width {
					return false
				}
				append_count++
			}
		}
	}
	return append_count == 1
}

// Handle sum() call
fn visit_sum(mut t VTranspiler, node Call, args []string) (string, bool, string) {
	total := 'arrays.sum(${args[0]}) or { 0 }'
	// Accumulate in Python order, starting from the supplied seed.
	mut starts := []Expr{}
	if start := python_sum_start(node) { starts << start }
	sequence := node.args[0]
	mut sum_operands := [sequence]
	sum_operands << starts
	unbounded := t.integer_growth_point('sum', sum_operands, false)
	mut elem_type := t.infer_iter_elem_type(sequence)
	if elem_type == '' {
		sequence_type := t.infer_expr_type(sequence)
		if sequence_type.starts_with('[]') {
			elem_type = sequence_type[2..]
		}
	}
	if sequence is List && sequence.elts.all(it is Constant && t.has_builtin_type(it)) {
		mut float_at := -1
		for i, element in sequence.elts {
			if t.infer_expr_type(element) in ['f32', 'f64', 'float'] {
				float_at = i
				break
			}
		}
		if float_at >= 0 && sequence.elts.any(native_integer_type(t.infer_expr_type(it))) {
			mut seed := '0'
			mut split := float_at
			if starts.len == 1 {
				start_type := t.infer_expr_type(starts[0])
				if start_type in ['f32', 'f64', 'float'] {
					split = 0
					seed = args[1]
				} else if native_integer_type(start_type) {
					seed = native_integer_input(start_type, args[1])
				} else {
					return t.unsupported_site('mixed_sum', 'mixed sum needs a numeric start', ''), true, ''
				}
			}
			if split > 0 {
				prefix := sequence.elts[..split]
				before := prefix.map('int(${t.visit_expr(it)})')
				items := '[${before.join(', ')}]'
				sum_operands[0] = Expr(List{ elts: prefix })
				if t.integer_growth_point('sum', sum_operands, false) {
					seed = t.checked_integer('sum', [items, seed], node.loc)
				} else {
					t.add_using('arrays')
					seed = 'arrays.fold(${items}, ${seed}, |acc, item| acc + item)'
				}
			}
			after := sequence.elts[split..].map('f64(${t.visit_expr(it)})')
			helper := t.runtime_helper('sum_float_suffix')
			return '${helper}([${after.join(', ')}], f64(${seed}))', true, ''
		}
	}
	items := node.args[0]
	kind := python_numeric_arg_list_kind(t, items)
	if kind == 'uniform_sum_array' && node.args.len == 1 && node.keywords.len == 0 {
		t.add_using('math')
		t.runtime_helper('numeric_choice')
		t.runtime_helper('float_text')
		t.runtime_helper('float_sum')
		return '${t.runtime_helper('float_sum_uniform_tagged')}(${args[0]})', true, ''
	}
	if kind == 'one_shot_generator' {
		return t.unsupported_site('bound_generator_sum', 'a saved generator is exhausted by sum', ''), true, ''
	}
	if kind == 'empty' {
		return if starts.len == 1 { args[1] } else { '0' }, true, ''
	}
	if kind == 'mixed' {
		return t.unsupported_site('mixed_numeric_sum',
			'native numeric arrays lose Python float/int element identity', ''), true, ''
	}
	// A native []f64 does not establish homogeneous Python float elements.
	// Unproven float sums must not silently use the compensated-float path.
	if kind !in ['float', 'maybe_float'] && t.infer_expr_type(items) == '[]f64' {
		return t.unsupported_site('unproven_float_sum',
			'Python numeric element types are not statically proven', ''), true, ''
	}
	is_float_array := kind in ['float', 'maybe_float']
	default_start := node.args.len == 1 && node.keywords.len == 0
	float_start_type := if starts.len == 1 {
		t.division_operand_type(starts[0], t.infer_expr_type(starts[0]))
	} else {
		'int'
	}
	if is_float_array && float_start_type == 'bool' {
		return t.unsupported_site('bool_sum_start', 'a boolean seed needs Python addition', ''), true, ''
	}
	numeric_start := starts.len == 1 && float_start_type in ['int', 'i64', 'f64']
	if is_float_array && (default_start || numeric_start) {
		start := if starts.len == 1 { 'f64(${args[1]})' } else { '0.0' }
		integer_start := float_start_type in ['int', 'i64']
		t.add_using('math')
		if t.sum_may_return_integer_zero(node) {
			seed := if starts.len == 1 { 'int(${args[1]})' } else { '0' }
			t.runtime_helper('numeric_choice')
			t.runtime_helper('float_text')
			t.runtime_helper('float_sum')
			return '${t.runtime_helper('float_sum_optional')}(${args[0]}, ${seed})', true, ''
		}
		return '${t.runtime_helper('float_sum')}(${args[0]}, ${start}, ${integer_start})', true, ''
	}
	if native_integer_type(elem_type) && starts.len == args.len - 1 {
		if starts.len == 0 {
			if !unbounded { return total, true, 'arrays' }
			return t.checked_integer('sum', [args[0], '0'], node.loc), true, ''
		}
		start_type := t.infer_expr_type(starts[0])
		if native_integer_type(start_type) {
			start := native_integer_input(start_type, args[1])
			if !unbounded {
				return 'int(arrays.fold(${args[0]}, ${start}, |acc, item| acc + int(item)))', true, 'arrays'
			}
			return t.checked_integer('sum', [args[0], start], node.loc), true, ''
		}
	}
	if starts.len == 1 {
		start := starts[0]
		// -s has the type of s
		typed := if start is UnaryOp && start.op is USub { *start.operand } else { start }
		start_type := t.infer_expr_type(typed)
		if start_type == 'f64' || (start_type in ['int', 'i64'] && elem_type == 'f64') {
			// an f64 seed, so that an int start does not make the fold an int one
			return 'arrays.fold(${args[0]}, f64(${args[1]}), |acc, x| acc + x)', true, 'arrays'
		}
		if native_integer_type(start_type) {
			seed := native_integer_input(start_type, args[1])
			return t.checked_integer('inferred_sum', [args[0], seed], node.loc), true, ''
		}
	}
	if elem_type !in ['f32', 'f64', 'float'] {
		return t.checked_integer('inferred_sum', [args[0], '0'], node.loc), true, ''
	}
	return t.unsupported_site('unproven_float_sum', 'Python numeric element types are not statically proven', ''), true, ''
}

// Handle sorted() call
fn visit_sorted(args []string) (string, bool) {
	return '(fn (a []Any) []Any { mut b := a.clone(); b.sort(); return b }(${args[0]}))', true
}

// The element and key types `<` orders in V as in Python.
const sort_scalar_types = ['int', 'i64', 'f64', 'string']!

// sort_order returns the key expression on `it` and the descending flag for a native sort.
fn sort_order(mut t VTranspiler, node Call, elem string) ?(string, bool) {
	mut reverse := false
	mut key_code := ''
	for kw in node.keywords {
		name := kw.arg or { return none }
		if name == 'reverse' {
			if kw.value !is Constant {
				return none
			}
			value := (kw.value as Constant).value
			if value is bool {
				reverse = value
			} else {
				return none
			}
		} else if name == 'key' {
			key := kw.value
			if key is Constant && (key as Constant).value is NoneValue {
				continue
			}
			// NaNs make float comparison non-transitive. V's sort does not use
			// CPython's Timsort comparison sequence, even with an index tie-break.
			if elem == 'f64' || (key is Name && t.func_return_types[key.id] == 'f64')
				|| (key is Lambda && get_expr_annotation(*key.body) in ['float', 'f64']) {
				key_code = '__py2v_non_total_float_key__'
			} else {
				key_code = sort_key_call(mut t, key, elem, 'it')?
			}
		} else {
			return none
		}
	}
	if key_code == '' && elem !in sort_scalar_types {
		return none
	}
	return key_code, reverse
}

// sort_key_call returns the V code of the sort key `key` applied to `operand`, an
// element of type `elem`, or none.
fn sort_key_call(mut t VTranspiler, key Expr, elem string, operand string) ?string {
	match key {
		Name {
			if key.id == 'len' && (elem == 'string' || elem.starts_with('[]')) {
				return if elem == 'string' { '${operand}.len_utf8()' } else { '${operand}.len' }
			}
			if key.id == 'abs' && elem in ['int', 'i64', 'f64'] {
				t.add_using('math')
				return 'math.abs(${operand})'
			}
			if t.func_return_types[key.id] in sort_scalar_types {
				return '${t.visit_expr(key)}(${operand})'
			}
		}
		Attribute {
			if elem == 'string' && key.value is Name && (key.value as Name).id == 'str' {
				if get_expr_annotation(key) == 'py2v_ascii_sort_key' && key.attr in [
					'lower',
					'upper',
				] {
					return '${operand}.to_${key.attr}()'
				}
				if key.attr == 'lower' {
					// V's case conversion is not equivalent to Python's full Unicode mapping.
					t.add_using('pyrt')
					return 'pyrt.str(pyrt.lower(${operand}) or { panic(err.msg()) })'
				}
				if key.attr == 'upper' {
					t.add_using('pyrt')
					return 'pyrt.str(pyrt.upper(${operand}) or { panic(err.msg()) })'
				}
			}
		}
		Lambda {
			if key.args.args.len != 1 || !expr_reads_only(*key.body, key.args.args[0].arg) {
				return none
			}
			// The body is emitted with the parameter spelled as the operand. The key must
			// be a scalar; the type of a field (`lambda x: x.attr`) is not known here and
			// is taken to be one.
			param := key.args.args[0].arg
			orig_var_types := t.var_types.clone()
			outer_rename := t.renamed_idents[param] or { '' }
			t.var_types[param] = elem
			t.var_types[operand] = elem
			t.renamed_idents[param] = operand
			result := t.infer_expr_type(*key.body)
			body := t.visit_expr(*key.body)
			t.var_types = orig_var_types.clone()
			if outer_rename == '' {
				t.renamed_idents.delete(param)
			} else {
				t.renamed_idents[param] = outer_rename
			}
			if result in sort_scalar_types || (result == '' && *key.body is Attribute) {
				return cmp_operand(body)
			}
		}
		else {}
	}
	return none
}

// expr_reads_only reports an expression built from the name `param`, constants, attributes,
// subscripts, arithmetic and `len`/`abs` alone: a V function literal can hold it without
// capturing anything.
fn expr_reads_only(e Expr, param string) bool {
	return match e {
		Name {
			e.id == param
		}
		Constant {
			true
		}
		Attribute {
			expr_reads_only(*e.value, param)
		}
		Subscript {
			expr_reads_only(*e.value, param) && expr_reads_only(*e.slice, param)
		}
		UnaryOp {
			expr_reads_only(*e.operand, param)
		}
		BinOp {
			expr_reads_only(*e.left, param) && expr_reads_only(*e.right, param)
		}
		Call {
			e.func is Name && (e.func as Name).id in ['len', 'abs'] && e.keywords.len == 0
				&& e.args.all(expr_reads_only(it, param))
		}
		else {
			false
		}
	}
}

// keyed_sort evaluates keys in input order and uses the original index to break ties.
fn keyed_sort(receiver string, elem string, key string, reverse bool, in_place bool) string {
	prefix := if in_place { 'mut ' } else { '' }
	result := if in_place { '' } else { ' []${elem}' }
	first := if reverse { 'rhs' } else { 'lhs' }
	second := if reverse { 'lhs' } else { 'rhs' }
	finish := if in_place {
		'\n\tordered := order.map(items[it])\n\tfor i, item in ordered { items[i] = item }'
	} else {
		'\n\treturn order.map(items[it])'
	}
	return '(fn (${prefix}items []${elem})${result} {\n' +
		'\tkeys := items.map(${key})\n\tmut order := []int{len: items.len, init: index}\n' +
		'\torder.sort_with_compare(fn [keys] (lhs &int, rhs &int) int {\n' +
		'\t\ta := keys[*${first}]\n\t\tb := keys[*${second}]\n' +
		'\t\tif a < b { return -1 }\n\t\tif b < a { return 1 }\n' +
		'\t\treturn if *lhs < *rhs { -1 } else if *lhs > *rhs { 1 } else { 0 }\n\t})' +
		'${finish}\n})(${prefix}${receiver})'
}

// visit_sorted_keywords emits sorted(xs, key=..., reverse=...) for known element types.
fn visit_sorted_keywords(mut t VTranspiler, node Call, args []string) ?string {
	if node.args.len != 1 {
		return none
	}
	mut arg_type := t.infer_expr_type(node.args[0])
	if arg_type == '' {
		arg_type = get_v_annotation(node.args[0])
	}
	mut receiver := as_receiver(args[0])
	mut elem := ''
	if arg_type == 'string' {
		receiver = "${receiver}.split('')"
		elem = 'string'
	} else if arg_type.starts_with('[]') && !arg_type.contains('Any') {
		elem = arg_type[2..]
	} else {
		return none
	}
	key, reverse := sort_order(mut t, node, elem)?
	if key == '__py2v_non_total_float_key__' {
		return t.unsupported_site('float_sort_key',
			'float keys may contain NaN and require CPython comparison order', '')
	}
	if key == '' {
		return if reverse { '${receiver}.sorted(a > b)' } else { '${receiver}.sorted()' }
	}
	return keyed_sort(receiver, elem, key, reverse, false)
}

// Handle map() call (not V's map data structure)
fn visit_map_builtin(args []string) (string, bool) {
	if args.len < 2 {
		return '', false
	}
	// map(func, iterable) -> iterable.map(func)
	return '${as_receiver(args[1])}.map(${args[0]})', true
}

// map_conversion translates `map(int, xs)`, `map(float, xs)` and
// `map(str, xs)`, where the builtin class is used as a function, to V's
// `xs.map(...)` with the conversion of one element `it`, chosen by the
// element type of `xs`. The result of a `split` is a list of strings, and a
// string is iterated by its characters. None when the element type is not
// known or has no exact conversion (`str` of a float or a bool is spelled
// differently in Python and V).
fn map_conversion(mut t VTranspiler, node Call, args []string) ?string {
	if node.args.len != 2 || args.len != 2 || node.args[0] !is Name {
		return none
	}
	iterable := node.args[1]
	mut iter_type := get_v_annotation(iterable)
	if iter_type != 'string' && !iter_type.starts_with('[]') {
		iter_type = t.infer_expr_type(iterable)
	}
	if iterable is Call {
		if iterable.func is Attribute {
			if (iterable.func as Attribute).attr in ['split', 'rsplit', 'splitlines'] {
				iter_type = '[]string'
			}
		}
	}
	mut receiver := as_receiver(args[1])
	if (node.args[0] as Name).api == 'builtins.repr' && iter_type == '[]string' {
		t.add_using('pyrt')
		return '${receiver}.map(pyrt.repr(pyrt.box(it)))'
	}
	if iter_type == 'string' {
		receiver = "${receiver}.split('')"
		iter_type = '[]string'
	}
	if !iter_type.starts_with('[]') {
		return none
	}
	class := (node.args[0] as Name).id
	elem := iter_type[2..]
	conversion := if class == 'int' && elem == 'string' {
		t.parse_native_integer(node, 'it', '10')
	} else if class == 'int' && elem in ['f64', 'f32'] {
		'int(it)'
	} else {
		map_element_conversion(class, elem) or { return none }
	}
	return '${receiver}.map(${conversion})'
}

fn map_element_conversion(class string, elem string) ?string {
	is_int := elem in ['int', 'i64']
	match class {
		'int' {
			if is_int || elem == 'bool' {
				return 'int(it)'
			}
		}
		'float' {
			if elem == 'string' {
				return 'it.f64()'
			}
			if is_int || elem == 'f64' {
				return 'f64(it)'
			}
		}
		'str' {
			if is_int || elem == 'string' {
				return 'it.str()'
			}
		}
		else {}
	}
	return none
}

// Handle filter() call
fn visit_filter(args []string) (string, bool) {
	if args.len < 2 {
		return '', false
	}
	// filter(func, iterable) -> iterable.filter(func)
	return '${as_receiver(args[1])}.filter(${args[0]})', true
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
			ptype = t.typename_from_annotation(*ann)
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
			t.var_types[name] = t.typename_from_annotation(*ann)
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
	if lam.list_identity_error != '' {
		return 'fn (${params.join(', ')}) ${ret_type} {\n' +
			t.indent_code(t.list_identity_refusal(lam.list_identity_error), 1) + '\n}'
	}
	body := t.visit_expr(lam.body)
	stripped := strip_outer_parens(body)
	return 'fn (${params.join(', ')}) ${ret_type} {\n\treturn ${stripped}\n}'
}

// Handle all() call
fn visit_all(args []string) (string, bool) {
	return '${as_receiver(args[0])}.all(it)', true
}

// Handle any() call (builtin, not the type)
fn visit_any_builtin(args []string) (string, bool) {
	return '${as_receiver(args[0])}.any(it)', true
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

// literal_attr_name returns the attribute a `getattr`, `setattr` or `hasattr`
// names when its name argument is a string literal that spells an identifier,
// and none for a name computed at run time (a variable, an f-string with
// fields), which no V field access can express.
fn literal_attr_name(arg string) ?string {
	if arg.len < 3 || arg[0] !in [`'`, `"`] || arg[arg.len - 1] != arg[0] {
		return none
	}
	name := arg[1..arg.len - 1]
	if name[0].is_digit() {
		return none
	}
	for c in name {
		if !(c.is_letter() || c.is_digit() || c == `_`) {
			return none
		}
	}
	return name
}

// Handle getattr(obj, name) / getattr(obj, name, default)
fn visit_getattr(args []string) (string, bool) {
	if args.len >= 2 {
		attr := literal_attr_name(args[1]) or {
			// A call to a function that does not exist: the gap shows at type checking.
			return 'py2v_unsupported_getattr_by_computed_name(${args.join(', ')})', true
		}
		if args.len >= 3 {
			return '${as_receiver(args[0])}.${attr} or { ${args[2]} }', true
		}
		return '${as_receiver(args[0])}.${attr}', true
	}
	return '', false
}

// Handle setattr(obj, name, value)
fn visit_setattr(args []string) (string, bool) {
	if args.len >= 3 {
		attr := literal_attr_name(args[1]) or {
			return 'py2v_unsupported_setattr_by_computed_name(${args.join(', ')})', true
		}
		return '${as_receiver(args[0])}.${attr} = ${args[2]}', true
	}
	return '', false
}

// Handle hasattr(obj, name)
fn visit_hasattr(args []string) (string, bool) {
	if args.len >= 2 {
		attr := literal_attr_name(args[1]) or {
			return 'py2v_unsupported_hasattr_by_computed_name(${args.join(', ')})', true
		}
		// V structs always have their fields; use compile-time check approximation
		return '(typeof(${as_receiver(args[0])}.${attr}).name != "")', true
	}
	return '', false
}

// isinstance_of_known_type decides `isinstance(name, cls)` while translating,
// when the frontend found `name` to be a parameter annotated with one of the
// builtin classes `int`, `float`, `str`, `bool`, `list` or `dict`, and `cls`
// is one of those six or a tuple of them. V's `is` only works on sum types
// and interfaces, and a V parameter of such a type cannot hold anything else,
// so the answer is a constant. As in Python, a bool is also an int.
fn isinstance_of_known_type(node Call) ?string {
	if node.isinstance_dynamic_types || node.subject_class == '' || node.args.len != 2 {
		return none
	}
	classes := match node.args[1] {
		Name { [node.args[1]] }
		Tuple { (node.args[1] as Tuple).elts }
		else { return none }
	}
	if classes.len == 0 {
		return none
	}
	mut result := false
	for cls in classes {
		if cls !is Name {
			return none
		}
		name := (cls as Name).id
		if name !in ['int', 'float', 'str', 'bool', 'list', 'dict', 'tuple', 'set', 'bytes'] {
			return none
		}
		if name == node.subject_class || (name == 'int' && node.subject_class == 'bool') {
			result = true
		}
	}
	return result.str()
}

// Handle isinstance() call
fn visit_isinstance(mut t VTranspiler, node Call, args []string) (string, bool) {
	if node.args.len != 2 { return 'py2v_unsupported_isinstance(${args.join(', ')})', true }
	type_expr := node.args[1]
	if node.isinstance_nominal != '' && expr_class_path(type_expr) in t.registry.class_names {
		return node.isinstance_nominal, true
	}
	if type_expr is Tuple && type_expr.elts.len == 0 {
		return '${t.runtime_helper('isinstance_empty')}(${args[0]})', true
	}
	if node.isinstance_dynamic_types || !isinstance_static_types(type_expr) {
		return 'py2v_unsupported_dynamic_isinstance(${args.join(', ')})', true
	}
	if t.infer_expr_type(node.args[0]) == 'Py2vNumber' && type_expr is Name {
		if type_expr.id in ['int', 'float'] {
			typ := if type_expr.id == 'float' { 'f64' } else { 'int' }
			return '${args[0]} is ${typ}', true
		}
	}
	// V's `is` is illegal for a concrete struct. For a proven local class type,
	// an exact class match is necessarily true; otherwise refuse until
	// inheritance and runtime identity have been established.
	subject_type := t.map_type(t.infer_expr_type(node.args[0])).trim_left('&')
	if subject_type in t.local_class_names.values() {
		mut checked := []Expr{}
		if type_expr is Tuple {
			checked = type_expr.elts.clone()
		} else {
			checked << type_expr
		}
		for candidate in checked {
			if candidate is Name && !t.is_bound_in_scope(candidate.id)
				&& candidate.id !in t.local_idents && candidate.id !in t.module_idents
				&& candidate.id in t.local_class_names
				&& t.local_class_name(candidate.id) == subject_type {
				return 'true', true
			}
		}
		return 'py2v_unsupported_concrete_isinstance(${args.join(', ')})', true
	}
	if type_expr is Tuple {
		mut parts := []string{}
		for elt in type_expr.elts {
			typ := if elt is Name && elt.id in t.local_class_names && !t.is_bound_in_scope(elt.id) {
				t.local_class_name(elt.id)
			} else {
				t.visit_expr(elt)
			}
			parts << '${args[0]} is ${typ}'
		}
		if parts.len > 1 {
			return '(${parts.join(' || ')})', true
		}
		if parts.len == 1 {
			return parts[0], true
		}
	}
	// V `is` checks the static (sum-type) variant; inherited types need
	// manual adaptation if the hierarchy is not a V sum type.
	target_type := if type_expr is Name && type_expr.id in t.local_class_names
		&& !t.is_bound_in_scope(type_expr.id) {
		t.local_class_name(type_expr.id)
	} else {
		args[1]
	}
	return '${args[0]} is ${target_type}', true
}

fn isinstance_static_types(expr Expr) bool {
	return match expr {
		Name { true }
		Attribute {
			expr.value is Name || (expr.value is Attribute && isinstance_static_types(expr.value))
		}
		Tuple { expr.elts.all(it is Name || (it is Attribute && isinstance_static_types(it))) }
		else { false }
	}
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
fn visit_divmod(mut t VTranspiler, node Call, args []string) (string, bool) {
	if args.len != 2 { return '', false }
	// This helper boxes integers as i64: a proven u64 can lose its high bit.
	if t.has_wide_args(node.args) {
		return t.refuse_wide('divmod of an unsigned value would narrow through i64'), true
	}
	left_raw := t.division_operand_type(node.args[0], t.infer_expr_type(node.args[0]))
	right_raw := t.division_operand_type(node.args[1], t.infer_expr_type(node.args[1]))
	// A unary float retains the frontend annotation `float`, whereas a
	// literal constant is inferred as `f64`. Both select a native float pair.
	left := if left_raw == 'float' { 'f64' } else { left_raw }
	right := if right_raw == 'float' { 'f64' } else { right_raw }
	if native_integer_type(left) && native_integer_type(right) {
		return t.checked_integer('divmod', [native_integer_input(left, args[0]),
			native_integer_input(right, args[1])], node.loc), true
	}
	kind := if left in ['int', 'f64', 'f32'] && right in ['int', 'f64', 'f32'] {
		'divmod_float'
	} else {
		'divmod_value'
	}
	t.add_using('pyrt')
	return '${t.runtime_helper(kind)}(${args.join(', ')})', true
}

// Handle ord() call - get unicode code point of character
fn visit_ord(mut t VTranspiler, node Call, args []string) (string, bool) {
	if t.infer_expr_type(node.args[0]) == 'string' {
		return 'int(${as_receiver(args[0])}.runes()[0])', true
	}
	return '${as_receiver(args[0])}[0]', true
}

// Handle chr() call - get character from code point
fn visit_chr(args []string) (string, bool) {
	// Return the rune expression itself; do not call .str()
	return 'rune(${args[0]})', true
}

// Handle reversed() call
fn visit_reversed(mut t VTranspiler, node Call, args []string) (string, bool) {
	if args.len != 1 {
		return '', false
	}
	if t.infer_expr_type(node.args[0]) == 'string' {
		return '${as_receiver(args[0])}.runes().reverse().map(it.str())', true
	}
	return '${as_receiver(args[0])}.reverse()', true
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
			if t.has_wide_args(node.args) {
				return DispatchResult{t.refuse_wide('range may narrow an unsigned bound'), true, ''}
			}
			code, handled := visit_range(mut t, node, args)
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
			code, handled := visit_int(mut t, node, args)
			return DispatchResult{code, handled, ''}
		}
		'float' {
			code, handled := visit_float(node, args)
			return DispatchResult{code, handled, ''}
		}
		'str' {
			code, handled := visit_str(mut t, node, args)
			return DispatchResult{code, handled, ''}
		}
		'len' {
			code, handled := visit_len(args)
			return DispatchResult{code, handled, ''}
		}
		'min' {
			if node.args.len == 1 && python_numeric_arg_list_kind(t, node.args[0]) in [
				'empty',
				'mixed',
			] {
				return DispatchResult{t.unsupported_site('min_numeric_shape',
					'empty or mixed numeric lists need Python ValueError and type preservation', ''), true, ''}
			}
			// Inferred V numeric types do not prove runtime Python value identity.
			// Only literal-proven int/float mixtures are safe to recognize here.
			if node.args.len == 2
				&& python_numeric_literal_kind(t, node.args[0]) in ['int', 'float']
				&& python_numeric_literal_kind(t, node.args[1]) in ['int', 'float']
				&& python_numeric_literal_kind(t, node.args[0]) != python_numeric_literal_kind(t, node.args[1]) {
				return DispatchResult{t.unsupported_site('min_mixed_numeric',
					'mixed numeric extrema preserve the winning Python type', ''), true, ''}
			}
			if node.args.len == 2 && node.keywords.len == 0
				&& node.args.all((it is Name || it is Constant) && t.infer_expr_type(it) == 'int') {
				return DispatchResult{'math.min(${args[0]}, ${args[1]})', true, 'math'}
			}
			code, handled, using := visit_min(args)
			return DispatchResult{code, handled, using}
		}
		'max' {
			if node.args.len == 1 && python_numeric_arg_list_kind(t, node.args[0]) in [
				'empty',
				'mixed',
			] {
				return DispatchResult{t.unsupported_site('max_numeric_shape',
					'empty or mixed numeric lists need Python ValueError and type preservation', ''), true, ''}
			}
			// Inferred V numeric types do not prove runtime Python value identity.
			// Only literal-proven int/float mixtures are safe to recognize here.
			if node.args.len == 2
				&& python_numeric_literal_kind(t, node.args[0]) in ['int', 'float']
				&& python_numeric_literal_kind(t, node.args[1]) in ['int', 'float']
				&& python_numeric_literal_kind(t, node.args[0]) != python_numeric_literal_kind(t, node.args[1]) {
				return DispatchResult{t.unsupported_site('max_mixed_numeric',
					'mixed numeric extrema preserve the winning Python type', ''), true, ''}
			}
			if node.args.len == 2 && node.keywords.len == 0
				&& node.args.all((it is Name || it is Constant) && t.infer_expr_type(it) == 'int') {
				return DispatchResult{'math.max(${args[0]}, ${args[1]})', true, 'math'}
			}
			code, handled, using := visit_max(args)
			return DispatchResult{code, handled, using}
		}
		'abs' {
			if node.args.len == 1 && t.infer_expr_type(node.args[0]) == 'Py2vNumber' {
				return DispatchResult{'${t.runtime_helper('numeric_abs')}(${args[0]})', true, 'math'}
			}
			if node.args.len == 1 && t.has_u64_bits(node.args[0]) {
				return DispatchResult{args[0], true, ''}
			}
			code, handled, using := visit_abs(args)
			return DispatchResult{code, handled, using}
		}
		'round' {
			if node.args.len == 2 && node.keywords.len == 0
				&& t.infer_expr_type(node.args[0]) == 'Py2vNumber' {
				if digits := literal_signed_integer(node.args[1]) {
					if digits >= 0 && digits <= 16 {
						return DispatchResult{'${t.runtime_helper('numeric_round_sig')}(${args[0]}, ${args[1]})', true, 'math'}
					}
				}
				return DispatchResult{t.unsupported_site('numeric_round_digits',
					'tagged numeric round needs proven nonnegative decimal digits', ''), true, ''}
			}
			if node.args.len == 1 && node.keywords.len == 0 {
				typ := t.infer_expr_type(node.args[0])
				if is_v_int_type(typ) {
					return DispatchResult{args[0], true, ''}
				}
				if typ == 'bool' {
					return DispatchResult{'int(${args[0]})', true, ''}
				}
				if typ in ['f32', 'f64', 'float'] {
					code := 'int(math.round_to_even(${as_f64_argument(typ, args[0])}))'
					return DispatchResult{code, true, 'math'}
				}
			}
			code, handled, using := visit_round(args)
			return DispatchResult{code, handled, using}
		}
		'floor' {
			typ := t.infer_expr_type(node.args[0])
			if native_integer_type(typ) {
				return DispatchResult{native_integer_input(typ, args[0]), true, ''}
			}
			code := 'int(math.floor(${as_f64_argument(typ, args[0])}))'
			return DispatchResult{code, true, 'math'}
		}
		'pow' {
			if t.has_wide_args(node.args) {
				return DispatchResult{t.refuse_wide('pow has no proven unsigned result bound'), true, ''}
			}
			code, handled, using := visit_pow(mut t, node, args)
			return DispatchResult{code, handled, using}
		}
		'sum' {
			if t.has_wide_args(node.args)
				|| (node.args.len > 0 && t.infer_iter_elem_type(node.args[0]) == 'u64') {
				return DispatchResult{t.refuse_wide('sum may exceed u64'), true, ''}
			}
			code, handled, using := visit_sum(mut t, node, args)
			return DispatchResult{code, handled, using}
		}
		'sorted' {
			// A list of known scalar element type, or a str, sorts with V's own
			// `.sorted()`, which keeps the element type; the fallback below is `[]Any`.
			if node.args.len == 1 && node.keywords.len == 0 {
				mut arg_type := t.infer_expr_type(node.args[0])
				if arg_type == '' {
					// what the frontend's inference found for the expression
					arg_type = get_v_annotation(node.args[0])
				}
				first := node.args[0]
				if arg_type == '' && first is GeneratorExp {
					// a generator of strings is emitted as an array of strings
					if get_v_annotation(first.elt) == 'string' {
						arg_type = '[]string'
					}
				}
				if arg_type in ['[]int', '[]i64', '[]f64', '[]string'] {
					return DispatchResult{'${as_receiver(args[0])}.sorted()', true, ''}
				}
				if arg_type == 'string' {
					return DispatchResult{"${as_receiver(args[0])}.split('').sorted()", true, ''}
				}
			}
			if node.keywords.len > 0 {
				if ordered := visit_sorted_keywords(mut t, node, args) {
					return DispatchResult{ordered, true, ''}
				}
			}
			code, handled := visit_sorted(args)
			return DispatchResult{code, handled, ''}
		}
		'map' {
			// Construct typed closure when first arg is a Lambda AST node
			if node.args.len > 0 {
				first := node.args[0]
				if first is Lambda {
					lam := first as Lambda
					iter_expr := if node.args.len > 1 {
						node.args[1]
					} else {
						Expr(Constant{
							value: NoneValue{}
						})
					}
					closure := build_typed_lambda_closure(mut t, lam, iter_expr)
					iter_code := as_receiver(args[1])
					return DispatchResult{'${iter_code}.map(${closure})', true, ''}
				}
				if converted := map_conversion(mut t, node, args) {
					return DispatchResult{converted, true, ''}
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
					iter_expr := if node.args.len > 1 {
						node.args[1]
					} else {
						Expr(Constant{
							value: NoneValue{}
						})
					}
					closure := build_typed_lambda_closure(mut t, lam, iter_expr)
					iter_code := as_receiver(args[1])
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
			if known := isinstance_of_known_type(node) {
				return DispatchResult{known, true, ''}
			}
			code, handled := visit_isinstance(mut t, node, args)
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
			// `set(xs)` of a list, a tuple or a str holds each value once, in order of
			// first occurrence. A set literal or comprehension already does. An argument
			// of unknown type is passed through as before.
			if node.args.len == 1 && node.keywords.len == 0 {
				arg := node.args[0]
				mut arg_type := t.infer_expr_type(arg)
				if arg_type == '' {
					arg_type = get_v_annotation(arg)
				}
				if arg is Set || arg is SetComp {
					return DispatchResult{args[0], true, ''}
				}
				if arg_type == 'string' {
					return DispatchResult{"${t.runtime_helper('distinct')}(${as_receiver(args[0])}.split(''))", true, ''}
				}
				if arg_type.starts_with('[]') || arg is List || arg is Tuple || arg is ListComp {
					return DispatchResult{'${t.runtime_helper('distinct')}(${args[0]})', true, ''}
				}
				if arg is BinOp && arg.op is Add && args[0].starts_with('arrays.append(') {
					return DispatchResult{t.unsupported_site('set_concat_order',
						'set constructed from concatenated lists needs a proven order-independent use', ''), true, ''}
				}
			}
			code, handled := visit_set_fn(args)
			return DispatchResult{code, handled, ''}
		}
		'dict' {
			code, handled := visit_dict_fn(args)
			return DispatchResult{code, handled, ''}
		}
		'divmod' {
			code, handled := visit_divmod(mut t, node, args)
			return DispatchResult{code, handled, ''}
		}
		'sys.exit' {
			code, handled := visit_sys_exit(args)
			return DispatchResult{code, handled, ''}
		}
		'ord' {
			code, handled := visit_ord(mut t, node, args)
			return DispatchResult{code, handled, ''}
		}
		'chr' {
			code, handled := visit_chr(args)
			return DispatchResult{code, handled, ''}
		}
		'bin' {
			if args.len != 1 {
				return DispatchResult{'', false, ''}
			}
			if t.has_u64_bits(node.args[0]) {
				return DispatchResult{"('0b' + strconv.format_uint(${args[0]}, 2))", true, 'strconv'}
			}
			return DispatchResult{'${t.runtime_helper('bin')}(i64(${args[0]}))', true, 'strconv'}
		}
		'hex' {
			if args.len == 1 && t.has_u64_bits(node.args[0]) {
				return DispatchResult{"('0x' + ${as_receiver(args[0])}.hex())", true, ''}
			}
			return DispatchResult{'', false, ''}
		}
		'reversed' {
			code, handled := visit_reversed(mut t, node, args)
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

// dispatch_random_func maps a call into Python's random module to V's rand module.
// V's ranges exclude the upper end, so `randint(a, b)`, which includes b, asks for b + 1.
// The V functions return a result; a failure (an empty range or list) stops the program
// as Python's exception would.
pub fn dispatch_random_func(mut t VTranspiler, fname string, args []string) (string, bool) {
	code := match fname['random.'.len..] {
		'random' {
			if args.len != 0 {
				return '', false
			}
			'rand.f64()'
		}
		'randint' {
			if args.len != 2 {
				return '', false
			}
			upper := if code_prec(args[1]) == atom_prec { args[1] } else { '(${args[1]})' }
			'(rand.int_in_range(${args[0]}, ${upper} + 1) or { panic(err) })'
		}
		'randrange' {
			if args.len == 1 {
				'(rand.intn(${args[0]}) or { panic(err) })'
			} else if args.len == 2 {
				'(rand.int_in_range(${args[0]}, ${args[1]}) or { panic(err) })'
			} else {
				return '', false
			}
		}
		'uniform' {
			if args.len != 2 {
				return '', false
			}
			'(rand.f64_in_range(${args[0]}, ${args[1]}) or { panic(err) })'
		}
		'choice' {
			if args.len != 1 {
				return '', false
			}
			'(rand.element(${args[0]}) or { panic(err) })'
		}
		'sample' {
			if args.len != 2 {
				return '', false
			}
			'(rand.choose(${args[0]}, ${args[1]}) or { panic(err) })'
		}
		'shuffle' {
			if args.len != 1 {
				return '', false
			}
			'rand.shuffle(mut ${args[0]}) or { panic(err) }'
		}
		else {
			return '', false
		}
	}
	t.add_using('rand')
	return code, true
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
				return '${as_receiver(args[0])}[..${args[1]}]', true
			}
			if args.len >= 3 {
				return '${as_receiver(args[0])}[${args[1]}..${args[2]}]', true
			}
			return '', false
		}
		'repeat' {
			// itertools.repeat(x, n) → []T{len: n, init: x}
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
			return '[][]Any{} /* itertools.zip_longest: use arrays.group or manual padding loop */', true
		}
		'product' {
			// itertools.product(a, b) — nested loops; emit stub
			return '[][]Any{} /* itertools.product(${args.join(', ')}): use nested for loops */', true
		}
		'combinations', 'combinations_with_replacement' {
			return '[][]Any{} /* itertools.${fn_name}(${args.join(', ')}): no direct V equivalent */', true
		}
		'permutations' {
			return '[][]Any{} /* itertools.permutations(${args.join(', ')}): no direct V equivalent */', true
		}
		'groupby' {
			return '[][]Any{} /* itertools.groupby(${args.join(', ')}): no direct V equivalent */', true
		}
		'takewhile' {
			if args.len >= 2 {
				return '${as_receiver(args[1])}.filter(${args[0]})', true
			}
			return '', false
		}
		'dropwhile' {
			return '[]Any{} /* itertools.dropwhile(${args.join(', ')}): no direct V equivalent */', true
		}
		'starmap' {
			return '[]Any{} /* itertools.starmap(${args.join(', ')}): use .map() with destructuring */', true
		}
		'accumulate' {
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

// dispatch_stdlib_const rewrites a `module.CONSTANT` reference for the Python
// standard library modules py2v models inline (errno, stat, signal).
fn dispatch_stdlib_const(attr_path string) string {
	parts := attr_path.split('.')
	if parts.len != 2 {
		return ''
	}
	mod := parts[0]
	name := parts[1]
	// V has no named constants for these, so the numeric value is emitted
	// bare. A trailing comment here would make vfmt rewrap the surrounding
	// expression across lines, so the name is not annotated.
	if mod == 'errno' {
		return errno_values[name] or { '' }
	}
	if mod == 'signal' {
		return signal_values[name] or { '' }
	}
	if mod == 'stat' {
		return stat_mode_masks[name] or { '' }
	}
	if mod == 'fcntl' {
		// V's os package has no advisory locking, so the lock modes are only
		// meaningful alongside the fcntl calls that are stubbed out.
		return fcntl_values[name] or { '' }
	}
	return ''
}

// dispatch_stdlib_call rewrites a `module.func(args)` call for the Python
// standard library modules py2v models inline.
pub fn dispatch_stdlib_call(mut t VTranspiler, mod string, fname string, args []string) (string, bool) {
	if mod == 'stat' {
		// `S_ISxxx(mode)` is a masked comparison against the file-type bits.
		if mask_name := stat_mode_predicates[fname] {
			if args.len == 1 {
				mask := stat_mode_masks[mask_name]
				return '((${args[0]}) & ${stat_mode_masks['S_IFMT']}) == ${mask}', true
			}
			return '', false
		}
		// `S_ISUID`-style tests are a single bit.
		if fname in stat_bit_predicates {
			if args.len == 1 {
				idx := stat_bit_predicates.index(fname)
				return '((${args[0]}) & ${stat_bit_masks[idx]}) != 0', true
			}
		}
		// `S_IMODE(mode)` strips the file-type bits.
		if fname == 'S_IMODE' && args.len == 1 {
			return '(${args[0]}) & ${stat_mode_masks['S_IMODE']}', true
		}
		return '', false
	}
	if mod == 'warnings' {
		if fname == 'warn' {
			t.add_using('log')
			if args.len > 0 {
				return 'log.warn(${args[0]})', true
			}
			return 'log.warn("")', true
		}
		// Filtering and capture APIs have no V counterpart.
		if fname in ['filterwarnings', 'simplefilter', 'catch_warnings', 'resetwarnings'] {
			return '/* warnings.${fname}: no V equivalent */ true', true
		}
		return '', false
	}
	if mod == 'signal' {
		if fname == 'signal' {
			t.add_using('os')
			if args.len >= 2 {
				// os.signal_opt returns the previous handler and is the
				// panic-free variant of os.signal. Its `or` value must be a
				// SignalHandler, not a Signal.
				// V's SignalHandler takes an os.Signal, but a Python signal handler
				// takes none. The adapter ignores the value and calls the handler,
				// which keeps the user's function body intact.
				t.add_using('os')
				// V's SignalHandler takes an os.Signal but a Python handler takes
				// none, so wrap the call in an adapter closure. A handler that is
				// already an inline closure is passed through unchanged.
				handler := args[1]
				v_handler := if handler.starts_with('(fn') && handler.contains('os.Signal') {
					handler
				} else {
					'fn (_ os.Signal) { ${handler}() }'
				}
				return 'os.signal_opt(${args[0]}, ${v_handler}) or { os.SignalHandler(unsafe { nil }) }', true
			}
			return '', false
		}
		// These have no V counterpart.
		if fname in ['pthread_sigmask', 'set_wakeup_fd', 'alarm', 'pause'] {
			return '/* signal.${fname}: no V equivalent */ true', true
		}
		return '', false
	}
	if mod == 'fcntl' {
		// V's os package has no advisory file locking or fcntl-style calls.
		if fname in ['flock', 'lockf', 'fcntl', 'ioctl'] {
			return '/* ${mod}.${fname}: V os has no fcntl equivalent */ true', true
		}
	}
	return '', false
}

// dispatch_attr handles attribute accesses like sys.argv.
pub fn dispatch_attr(mut t VTranspiler, attr_path string) (string, bool) {
	{
		hit := dispatch_stdlib_const(attr_path)
		if hit.len > 0 {
			return hit, true
		}
	}
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
