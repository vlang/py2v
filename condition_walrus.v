module main

// condition_walrus_children follows evaluation in the enclosing scope. Lambdas
// and comprehensions retain their existing, separate lowering.
fn condition_walrus_children(expr Expr) []Expr {
	mut children := []Expr{}
	match expr {
		NamedExpr { children << *expr.value }
		UnaryOp { children << *expr.operand }
		BinOp {
			children << *expr.left
			children << *expr.right
		}
		BoolOp { children << expr.values }
		Compare {
			children << *expr.left
			children << expr.comparators
		}
		Call {
			children << *expr.func
			children << expr.args
			for keyword in expr.keywords {
				children << keyword.value
			}
		}
		Attribute { children << *expr.value }
		Subscript {
			children << *expr.value
			children << *expr.slice
		}
		Slice {
			if lower := expr.lower { children << *lower }
			if upper := expr.upper { children << *upper }
			if step := expr.step { children << *step }
		}
		List { children << expr.elts }
		Tuple { children << expr.elts }
		Set { children << expr.elts }
		Dict {
			for key in expr.keys {
				if present := key { children << present }
			}
			children << expr.values
		}
		IfExp {
			children << *expr.test
			children << *expr.body
			children << *expr.orelse
		}
		Await { children << *expr.value }
		YieldFrom { children << *expr.value }
		Starred { children << *expr.value }
		Yield {
			if value := expr.value { children << *value }
		}
		FormattedValue {
			children << *expr.value
			if spec := expr.format_spec { children << *spec }
		}
		JoinedStr { children << expr.values }
		else {}
	}
	return children
}

fn contains_condition_walrus(expr Expr) bool {
	if expr is NamedExpr {
		return true
	}
	for child in condition_walrus_children(expr) {
		if contains_condition_walrus(child) {
			return true
		}
	}
	return false
}

// Only these enclosing operators are rewritten. A call or other expression
// without a walrus remains an ordinary operand, with its existing translation.
// In particular, do not pull assignments out of arbitrary call arguments or
// conditional expressions without also lowering their evaluation rules.
fn condition_walrus_supported(expr Expr) bool {
	if !contains_condition_walrus(expr) {
		return true
	}
	match expr {
		NamedExpr {
			if expr.target !is Name {
				return false
			}
		}
		UnaryOp, BinOp {}
		BoolOp {
			if expr.values.len == 0 { return false }
		}
		Compare {
			if expr.ops.len == 0 || expr.ops.len != expr.comparators.len {
				return false
			}
		}
		else { return false }
	}
	for child in condition_walrus_children(expr) {
		if !condition_walrus_supported(child) {
			return false
		}
	}
	return true
}

// The caller uses this ordered list to reserve the targets in their enclosing
// scope before any conditional assignment is emitted.
fn condition_walrus_targets(expr Expr, mut names []string) {
	if expr is NamedExpr && expr.target is Name {
		name := (expr.target as Name).id
		if name !in names { names << name }
	}
	for child in condition_walrus_children(expr) {
		condition_walrus_targets(child, mut names)
	}
}

// Save a value before a later operand can change its source variable. Constants
// stay inline: they cannot change and may need the comparison's contextual type.
fn (mut t VTranspiler) condition_walrus_value_once(expr Expr, mut lines []string) Expr {
	if expr is Constant {
		return expr
	}
	return t.condition_walrus_temp(expr, false, mut lines)
}

fn (mut t VTranspiler) condition_walrus_temp(expr Expr, mutable bool, mut lines []string) Expr {
	name := t.new_tmp('walrus')
	value := t.visit_expr(expr)
	typ := t.condition_walrus_type(expr)
	kw := if mutable { 'mut ' } else { '' }
	lines << '${kw}${name} := ${value}'
	if typ != '' { t.var_types[name] = typ }
	return Expr(Name{
		id:           name
		ctx:          Load{}
		v_annotation: typ
	})
}

// A declaration outside the condition needs a type before its first assignment.
// Reuse existing inference and explicit hints; leave unknown types unknown.
fn (mut t VTranspiler) condition_walrus_type(expr Expr) string {
	typ := t.infer_expr_type(expr)
	if typ != '' { return typ }
	ann := get_expr_annotation(expr)
	if ann != '' {
		mapped := t.map_type(ann)
		if mapped != 'auto' { return mapped }
	}
	match expr {
		UnaryOp { return t.condition_walrus_type(*expr.operand) }
		NamedExpr { return t.condition_walrus_type(*expr.value) }
		Call {
			cls := t.constructor_name(expr)
			if cls != '' { return t.map_type(cls) }
		}
		IfExp {
			body := t.condition_walrus_type(*expr.body)
			otherwise := t.condition_walrus_type(*expr.orelse)
			if body == otherwise { return body }
		}
		else {}
	}
	return ''
}

// lower_if_walrus_expr is called only after condition_walrus_supported succeeds.
// Targets have mutable declarations in the enclosing scope. Preludes are kept
// inside the branch that evaluates the corresponding Python operand.
fn (mut t VTranspiler) lower_if_walrus_expr(expr Expr, mut lines []string) Expr {
	if !contains_condition_walrus(expr) {
		return expr
	}
	match expr {
		NamedExpr {
			value := t.lower_if_walrus_expr(*expr.value, mut lines)
			target := expr.target as Name
			typ := t.condition_walrus_type(value)
			if typ != '' {
				t.condition_walrus_types[target.id] = typ
				t.var_types[target.id] = typ
			}
			lines << '${t.visit_expr(*expr.target)} = ${t.visit_expr(value)}'
			return Expr(Name{
				...target
				ctx:          Load{}
				v_annotation: typ
			})
		}
		UnaryOp {
			operand := t.lower_if_walrus_expr(*expr.operand, mut lines)
			return Expr(UnaryOp{
				...expr
				operand: &operand
			})
		}
		BinOp {
			mut left := t.lower_if_walrus_expr(*expr.left, mut lines)
			if contains_condition_walrus(*expr.right) {
				left = t.condition_walrus_value_once(left, mut lines)
			}
			right := t.lower_if_walrus_expr(*expr.right, mut lines)
			return Expr(BinOp{
				...expr
				left:  &left
				right: &right
			})
		}
		BoolOp {
			first := t.lower_if_walrus_expr(expr.values[0], mut lines)
			result := t.condition_walrus_temp(first, true, mut lines)
			name := t.visit_expr(result)
			for value in expr.values[1..] {
				mut branch := []string{}
				right := t.lower_if_walrus_expr(value, mut branch)
				branch << '${name} = ${t.visit_expr(right)}'
				guard := if expr.op is And { name } else { '!${name}' }
				lines << 'if ${guard} {'
				lines << indent(branch.join('\n'), 1, '\t')
				lines << '}'
			}
			return result
		}
		Compare {
			left := t.lower_if_walrus_expr(*expr.left, mut lines)
			return t.lower_if_walrus_compare(expr, 0, left, mut lines)
		}
		else { return expr }
	}
}

// Chained comparisons reuse the middle value and evaluate the next comparator
// only after the preceding comparison succeeded.
fn (mut t VTranspiler) lower_if_walrus_compare(node Compare, index int, previous Expr,
	mut lines []string) Expr {
	more := index + 1 < node.ops.len
	mut left := previous
	if more || contains_condition_walrus(node.comparators[index]) {
		left = t.condition_walrus_value_once(left, mut lines)
	}
	mut right := t.lower_if_walrus_expr(node.comparators[index], mut lines)
	if more {
		right = t.condition_walrus_value_once(right, mut lines)
	}
	comparison := Expr(Compare{
		...node
		left:        &left
		ops:         [node.ops[index]]
		comparators: [right]
	})
	if !more {
		return comparison
	}
	result := t.condition_walrus_temp(comparison, true, mut lines)
	name := t.visit_expr(result)
	mut branch := []string{}
	next := t.lower_if_walrus_compare(node, index + 1, right, mut branch)
	branch << '${name} = ${t.visit_expr(next)}'
	lines << 'if ${name} {'
	lines << indent(branch.join('\n'), 1, '\t')
	lines << '}'
	return result
}
