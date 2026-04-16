@[translated]
module main

fn equation(x int, y int) bool {
	if smt_pre {
		assert x > 2
		assert y < 10
		assert x + 2 * y == 7
	}
	true
}

fn fequation(z f64) bool {
	if smt_pre {
		assert 9.8 + 2 * z == z + 9.11
	}
	true
}

fn main() {
	// import py2many.smt: no known V equivalent
	// import py2many.smt: no known V equivalent
	x := default_value(int)
	y := default_value(int)
	z := default_value(float)
	assert equation(x, y)
	assert fequation(z)
	check_sat()
	get_value([x, y, z])
}
