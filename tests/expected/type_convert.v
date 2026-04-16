@[translated]
module main

fn main_func() {
	println(int(3.7))
	println('42'.int())
	println(int(-3.9))
	println(f64(42))
	println('3.14'.f64())
	println((42))
	println((3.14))
	println(true)
	println(if (1 != 0) { 'True' } else { 'False' })
	println(if (0 != 0) { 'True' } else { 'False' })
	println(if ('hello'.len > 0) { 'True' } else { 'False' })
	println(if (''.len > 0) { 'True' } else { 'False' })
}

fn main() {
	main_func()
}
