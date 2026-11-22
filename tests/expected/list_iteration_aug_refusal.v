module main

fn main_func() {
	py2v_unsupported_list_identity1() // py2v: main_func: 4: resizing or reordering a shared list during iteration is not supported
}

@[noreturn]
fn py2v_unsupported_list_identity1() {
	panic('py2v_unsupported_list_identity: list aliases cannot be preserved')
}

fn main() {
	main_func()
}
