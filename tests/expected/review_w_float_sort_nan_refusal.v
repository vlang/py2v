module main

fn identity(x f64) f64 {
	return x
}

fn main_func() {
	numbers := [3.0, 'nan'.f64(), 2.0, 1.0, -1.0, 0.0]
	println(py2v_unsupported_float_sort_key('float keys may contain NaN and require CPython comparison order'))
}

fn main() {
	main_func()
}
