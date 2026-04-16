@[translated]
module main

fn test_global() {
	// global global_var  // V doesn't support global keyword
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
