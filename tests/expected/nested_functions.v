module main

fn outer(x int) int {
	inner := fn (y int) int {
		return y * 2
	}
	return inner(x) + 1
}

fn make_adder(n int) fn (int) int {
	py2v_capture1 := &n
	adder := fn [py2v_capture1] (x int) int {
		return x + (*py2v_capture1)
	}
	return adder
}

fn main_func() {
	println(outer(5))
	println(outer(10))
	add5 := make_adder(5)
	println(add5(10))
	println(add5(20))
}

fn main() {
	main_func()
}
