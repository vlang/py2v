module main

import v.ast

struct Scope {
mut:
	idents       map[string]&ast.IdentVar
	redirects map[string]string
	parent        &Scope = voidptr(0)
	children      []&Scope
}

fn (s &Scope) get_parent() &Scope {
	mut sc := s
	if isnil(sc.parent) {
		return sc
	}
	return sc.parent.get_parent()
}

fn (s &Scope) new_child() &Scope {
	mut sc := s
	sc.children << &Scope{parent: sc}
	return sc.children.last()
}

fn (s &Scope) get(name string) ?&ast.IdentVar {
	mut sc := s
	println(sc.idents.keys())
	if name in sc.idents {
		return sc.idents[name]
	}

	if isnil(sc.parent) {
		return none
	}

	return sc.parent.get(name)
}

fn (s &Scope) has(name string) bool {
	mut sc := s
	sc.get(name) or { return false }
	return true
}

fn (s &Scope) add(name string, identvar &ast.IdentVar) bool {
	mut sc := s
	if sc.has(name) {
		return false
	}

	sc.idents[name] = identvar
	return true
}

fn (s &Scope) redirect(name string) string {
	mut sc := s
	if name in sc.redirects {
		return sc.redirects[name]
	}

	if isnil(sc.parent) {
		return name
	}

	return sc.parent.redirect(name)
}
