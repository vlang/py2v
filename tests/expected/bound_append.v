module main

fn collect() []int {
	mut values := []int{}
	push := py2v_append_method1(mut values)
	push(3)
	push(7)
	return values
}

fn py2v_append_method1[T](mut items []T) fn (T) {
	return fn [mut items] [T](value T) { items << value }
}

fn main() {
	println(collect())
}
