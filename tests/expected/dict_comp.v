module main

fn show() {
	squares := (fn () map[int]i64 {
		mut result := map[int]i64{}
		for x in []int{len: 5, init: index} {
			result[x] = x * x
		}
		return result
	}())
	println(squares.len)
	evens := (fn () map[int]i64 {
		mut result := map[int]i64{}
		for x in []int{len: 10, init: index} {
			if x % 2 == 0 {
				result[x] = x * 2
			}
		}
		return result
	}())
	println(evens.len)
}

fn main() {
	show()
}
