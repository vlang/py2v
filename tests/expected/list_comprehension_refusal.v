py2v: grow: 9: a call may resize or reorder the list during iteration; this is not supported
py2v: main_func: 9: a call may resize or reorder the list during iteration; this is not supported
module main

fn grow(mut values []int, value int) int {
	py2v_unsupported_list_identity1() // py2v: grow: 9: a call may resize or reorder the list during iteration; this is not supported
}

fn main_func() {
	py2v_unsupported_list_identity1() // py2v: main_func: 9: a call may resize or reorder the list during iteration; this is not supported
}

@[noreturn]
fn py2v_unsupported_list_identity1() {
	panic('py2v_unsupported_list_identity: list aliases cannot be preserved')
}

fn main() {
	main_func()
}
