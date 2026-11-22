py2v: main_func: 4: shared list passed to an unresolved call; cannot preserve native list identity at this boundary
module main

fn main_func() {
	py2v_unsupported_list_identity1() // py2v: main_func: 4: shared list passed to an unresolved call; cannot preserve native list identity at this boundary
}

@[noreturn]
fn py2v_unsupported_list_identity1() {
	panic('py2v_unsupported_list_identity: list aliases cannot be preserved')
}

fn main() {
	main_func()
}
