module main

type Any = bool | int | i64 | f64 | string | []u8

fn sub(a int, b int) int {
	return a - b
}

fn main_func() {
	println(sub(10, 1))
	println(area(3, 2, 3, 10))
	println(negative(3, -7))
	println(text("it's", '!'))
	println(descend(3))
	println(first([11]))
}

fn area(w int, h int, depth int, scale int) int {
	return w * h * depth * scale
}

fn negative(a int, b int) int {
	return a - b
}

fn text(a string, b string) string {
	return a + b
}

fn descend(n int) int {
	if n == 0 {
		return 0
	}
	return 1 + descend(n - 1)
}

fn first(xs []int) int {
	return xs[0]
}

fn main() {
	main_func()
}
