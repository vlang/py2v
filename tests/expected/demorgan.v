@[translated]

module main

fn demorgan(a bool, b bool) bool {
	a && b == !!a || !b
}

fn main() {
	a := bool{}
	b := bool{}
	assert !demorgan(a, b)
	check_sat()
}
