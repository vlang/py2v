module main

// Rewriters for V AST transformations
// Note: Most rewriting is done in the Python frontend (ast_dump.py)
// This file contains V-side helpers for codegen-time transformations

// Rewrite dict.values() calls to dict.keys().map(dict[it])
// This is primarily handled in Python, but this helper can be used if needed
pub fn rewrite_dict_values(dict_expr string) string {
	return '${dict_expr}.keys().map(${dict_expr}[it])'
}

// Transform comprehension target variable references to 'it'
// Used when converting [x*2 for x in items] to items.map(it * 2)
pub fn rewrite_comprehension_var(expr string, var_name string) string {
	// Simple string replacement - in practice, the Python frontend handles this
	mut result := expr
	// Replace whole-word occurrences of var_name with 'it'
	// This is a simplified implementation
	result = result.replace(var_name, 'it')
	return result
}

// Check if an expression contains a walrus operator pattern
// Walrus operators should be lifted by the Python frontend
pub fn has_walrus_pattern(code string) bool {
	return code.contains(':=') && code.contains('if ')
}

// Transform None comparisons for integer types
// x == None with int -> x == 0
pub fn rewrite_none_compare_int(left_type string, op string, right_val string) string {
	if right_val == 'none' && left_type in v_width_rank {
		return '0'
	}
	return right_val
}

// AST-level rewriter state (for future use if needed)
pub struct RewriterState {
mut:
	redirects        map[string]string
	in_comprehension bool
}

pub fn new_rewriter_state() RewriterState {
	return RewriterState{
		redirects:        map[string]string{}
		in_comprehension: false
	}
}

// Add a variable redirect (e.g., comprehension var -> it)
pub fn (mut s RewriterState) add_redirect(from string, to string) {
	s.redirects[from] = to
}

// Clear all redirects
pub fn (mut s RewriterState) clear_redirects() {
	s.redirects.clear()
}

// Apply redirects to a variable name
pub fn (s RewriterState) apply_redirect(name string) string {
	return s.redirects[name] or { name }
}

// Enter comprehension context
pub fn (mut s RewriterState) enter_comprehension() {
	s.in_comprehension = true
}

// Exit comprehension context
pub fn (mut s RewriterState) exit_comprehension() {
	s.in_comprehension = false
	s.clear_redirects()
}
