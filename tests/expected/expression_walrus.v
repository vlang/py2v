module main

fn collect() []int {
	index := 0
	mut spans := [index, py2v_assign_expr1(&index, index + 1), index]
	spans << py2v_assign_expr1(&index, index + 2)
	println(index)
	return spans
}

fn py2v_assign_expr1[T](target &T, value T) T {
	unsafe { *target = value }
	return value
}

fn main() {
	println(collect())
}
