module main

// py2v:10: shared list passed to an unresolved call; cannot preserve native list identity at this boundary
fn main() {
	py2v_unsupported_list_identity()
}
