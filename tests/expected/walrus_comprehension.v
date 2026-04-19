module main

type Any = bool | int | i64 | f64 | string | []u8

fn squares_above(n int) list {
	return (fn () []Any {
		mut result := []Any{}
		for x in 0..n {
			y := x * x
			if y > 5 {
				result << y
			}
		}
		return result
	})()
}

fn evens_doubled(nums list) list {
	return (fn () []Any {
		mut result := []Any{}
		for x in nums {
			d := x * 2
			if d % 4 == 0 {
				result << d
			}
		}
		return result
	})()
}

fn nested_walrus(matrix list) list {
	return (fn () []Any {
		mut result := []Any{}
		for row in matrix {
			for z in row {
				w := z * 3
				if w > 6 {
					result << z
				}
			}
		}
		return result
	})()
}

fn main() {
	println(squares_above(8))
	println(evens_doubled([1, 2, 3, 4, 5, 6]))
	println(nested_walrus([[1, 2, 3], [4, 5, 6]]))
}
