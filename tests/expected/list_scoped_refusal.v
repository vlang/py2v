module main

import pyrt

pub struct Methods {
pub mut:
	values []int
}

fn (mut self Methods) refused() {
	py2v_unsupported_list_identity1() // py2v: Methods.refused: 41: resizing or reordering a shared list during iteration is not supported
}

fn (self Methods) unrelated() int {
	return 7
}

fn refused() {
	py2v_unsupported_list_identity1() // py2v: refused: 4: resizing or reordering a shared list during iteration is not supported
}

fn refused_groups() []int {
	py2v_unsupported_list_identity1() // py2v: refused_groups: 13: resizing or reordering a shared list during iteration is not supported
}

fn refused_lambda_callback() {
	println([0].filter(fn (_ int) bool {
		py2v_unsupported_list_identity1() // py2v: refused_lambda_callback.<lambda@24>: shared-list ordering comparison is not supported
	}).clone())
}

fn unrelated() {
	values := pyrt.list_ref[int]([4])
	mut alias := values
	alias.items << 5
	println(values.items.str())
}

fn refused_return() []int {
	py2v_unsupported_list_identity1() // py2v: refused_return: 52: resizing or reordering a shared list during iteration is not supported
}

fn refused_caller() {
	py2v_unsupported_list_identity1() // py2v: refused_caller: 52: resizing or reordering a shared list during iteration is not supported
}

fn refused_default() {
	py2v_unsupported_list_identity1() // py2v: refused_default: shared-list ordering comparison is not supported
}

fn refused_received() {
	py2v_unsupported_list_identity1() // py2v: refused_received: 76: shared list received from an unresolved call; cannot preserve native list identity at this boundary
}

@[noreturn]
fn py2v_unsupported_list_identity1() {
	panic('py2v_unsupported_list_identity: list aliases cannot be preserved')
}

fn main() {
	unrelated()
	println(Methods{}.unrelated())
}
