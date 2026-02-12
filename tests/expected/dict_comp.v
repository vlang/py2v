@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

fn show() {
	squares := (fn () map[string]Any {
		mut result := map[string]Any{}
		for x in []int{len: 5, init: index} {
			result[x] = (x * x)
		}
		return result
	}())
	println((squares.len).str())
	evens := (fn () map[string]Any {
		mut result := map[string]Any{}
		for x in []int{len: 10, init: index} {
			if (x % 2) == 0 {
				result[x] = (x * 2)
			}
		}
		return result
	}())
	println((evens.len).str())
}

fn main() {
	show()
}
