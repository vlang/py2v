module main

fn main_func() {
	mut values := [1e+16, 1.0, -1e+16]
	values[1] = 1
	println(py2v_unsupported_unproven_float_sum('Python numeric element types are not statically proven'))
}

fn main() {
	main_func()
}
