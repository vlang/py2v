module main

fn main_func() {
	t := [1, 2, 3]
	println(t)
	py2v_unpack1 := t
	mut a := py2v_unpack1[0]
	mut b := py2v_unpack1[1]
	mut c := py2v_unpack1[2]
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
