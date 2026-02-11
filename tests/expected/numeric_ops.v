@[translated]
module main

fn main_func() {
	println((17 / 5).str())
	println((-17 / 5).str())
	println((17 % 5).str())
	println((-17 % 5).str())
	println((2 ^ 10).str())
	println((3 ^ 4).str())
	a := 100
	println((a / 7).str())
	println((a % 7).str())
	println((a ^ 2).str())
	println((-5 / 2).str())
	println((-5 % 2).str())
}

fn main() {
	main_func()
}
