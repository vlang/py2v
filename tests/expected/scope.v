@[translated]
module main

fn test_global() {
	// global global_var: prefer mut parameter or struct field over __global
	global_var := 20
	println(global_var)
}

fn show() {
	test_global()
}

fn main() {
	global_var := 10
	show()
}
