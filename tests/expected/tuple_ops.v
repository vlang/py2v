@[translated]

module main

fn main_func() {
	t := [1, 2, 3]
	println(t)
	__unpack1 := t
	mut a := __unpack1[0]
	mut b := __unpack1[1]
	mut c := __unpack1[2]
	println(a)
	println(b)
	println(c)
	mut x := 10
	mut y := 20
	x, y = y, x
	println(x)
	println(y)
}

fn main() {
	main_func()
}
