@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

__global (
	bit   = BitVecAny{}
	myu32 = BitVecAny{}
	myu64 = BitVecAny{}
)
fn my_func1(x int, y int) int {
	// ...
}
