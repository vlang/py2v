@[translated]
module main

fn main_func() {
	println((int(3.7)).str())
	println(('42'.int()).str())
	println((int(-3.9)).str())
	println((f64(42)).str())
	println(('3.14'.f64()).str())
	println((42).str())
	println((3.14).str())
	println(true.str())
	println(if (1 != 0) { 'True' } else { 'False' })
	println(if (0 != 0) { 'True' } else { 'False' })
	println(if ('hello'.len > 0) { 'True' } else { 'False' })
	println(if (''.len > 0) { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
