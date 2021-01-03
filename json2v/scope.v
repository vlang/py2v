module main

import v.ast

[inline]
fn is_scoped(stmt ast.Stmt) bool {
	return match stmt {
		ast.FnDecl, ast.ForInStmt { true }
		else { false }
	}
}

[inline]
fn (mut t Transpiler) is_at_top() bool {
	return isnil(t.scope.parent)
}

[inline]
fn (mut t Transpiler) scope_up() {
	if isnil(t.scope.parent) {
		panic(@FN + ': no parent')
	}
	t.scope = t.scope.parent
}

[inline]
fn (mut t Transpiler) scope_down() {
	t.scope.children << &ast.Scope{parent: t.scope}
	t.scope = t.scope.children.last()
}
