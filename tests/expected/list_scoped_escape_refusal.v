py2v: <lambda@4>: shared-list ordering comparison is not supported
py2v: refused_reader: shared-list ordering comparison is not supported
py2v: refused_closure: 21: resizing or reordering a shared list during iteration is not supported
py2v: module-level list refusal: <module@1>: shared-list ordering comparison is not supported
py2v: module-level list refusal: <module@2>: shared-list ordering comparison is not supported
py2v: module-level list refusal: <module@3>: shared-list ordering comparison is not supported
py2v: module-level list refusal: <module@7>: shared-list ordering comparison is not supported
module main

const values = [1]

fn refused_default(value bool) bool {
	return value
}

fn refused_reader() []int {
	py2v_unsupported_list_identity1() // py2v: refused_reader: shared-list ordering comparison is not supported
}

fn refused_closure() {
	py2v_unsupported_list_identity1() // py2v: refused_closure: 21: resizing or reordering a shared list during iteration is not supported
}

fn unrelated() {
	println(42)
}

// py2v: module-level list refusal: <module@1>: shared-list ordering comparison is not supported

// py2v: module-level list refusal: <module@2>: shared-list ordering comparison is not supported

// py2v: module-level list refusal: <module@3>: shared-list ordering comparison is not supported

// py2v: module-level list refusal: <module@7>: shared-list ordering comparison is not supported

const py2v_list_identity_module_guard1 = py2v_unsupported_list_identity_module1()

@[noreturn]
fn py2v_unsupported_list_identity1() {
	panic('py2v_unsupported_list_identity: list aliases cannot be preserved')
}

fn main() {
	mut alias := values
	alias << 2
	refused_lambda := fn () string {
		py2v_unsupported_list_identity1() // py2v: <lambda@4>: shared-list ordering comparison is not supported
	}
	unrelated()
}
