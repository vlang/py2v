module main

type Any = bool | int | i64 | f64 | string | []u8

fn make_counter() fn () Any {
	mut count := 0
	increment := fn [mut count] () Any {
		count += 1
		return count
	}
	return increment
}

fn make_adder(n int) fn (int) int {
	mut total := 0
	add := fn [mut total, n] (x int) int {
		total += x + n
		return total
	}
	return add
}

fn main() {
	c := make_counter()
	println(c())
	println(c())
	add5 := make_adder(5)
	println(add5(1))
	println(add5(2))
}
