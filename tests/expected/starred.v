module main

fn show() {
	py2v_unpack1 := [1, 2, 3, 4, 5]
	mut first := py2v_unpack1[0]
	mut middle := py2v_unpack1[1..py2v_unpack1.len - 1]
	mut last := py2v_unpack1.last()
	println(first + ' ' + last)
}

fn main() {
	show()
}
