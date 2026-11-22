py2v: refused_walrus: 4: resizing or reordering a shared list during iteration is not supported
module main

fn refused_walrus() {
	py2v_unsupported_list_identity1() // py2v: refused_walrus: 4: resizing or reordering a shared list during iteration is not supported
}

fn unrelated() {
	println(7)
}

@[noreturn]
fn py2v_unsupported_list_identity1() {
	panic('py2v_unsupported_list_identity: list aliases cannot be preserved')
}

fn main() {
	unrelated()
}
