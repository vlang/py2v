@[translated]
module main

__global (
	x = default_value(int)
	y = default_value(int)
	z = default_value(float)
)
fn equation(x int, y int) bool {
	if smt_pre {
		assert x > 2
		assert y < 10
		assert (x + (2 * y)) == 7
	}

	true
}

fn fequation(z f64) bool {
	if smt_pre {
		assert (9.8 + (2 * z)) == (z + 9.11)
	}

	true
}

fn main() {
	assert equation(x, y)
	assert fequation(z)
	check_sat()
	get_value([x, y, z])
}
