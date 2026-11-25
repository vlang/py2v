module main

fn f() int {
	dummy := fn () int {
		return 0
	}
	mut saved := dummy
	for i_ in [1, 2, 3] {
		g := py2v_unsupported_closure_loop_capture(fn (i_ int) int {
			return i_
		})
		if i_ == 1 {
			saved = g
		}
	}
	return saved()
}

fn main() {
	println(f())
}
