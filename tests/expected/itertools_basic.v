module main

import arrays

type Any = bool | int | i64 | f64 | string | []u8

fn main() {
	nums := [1, 2, 3]
	letters := ['a', 'b']
	chained := arrays.flatten([nums, letters])
	sliced := nums[..2]
	repeated := []Any{len: 3, init: 7} // itertools.repeat
	pairs := [][]Any{} // itertools.product(nums, letters): use nested for loops
	println(chained)
	println(sliced)
	println(repeated)
}
