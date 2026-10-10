module main

fn demorgan(a bool, b bool) bool {
	a && b == !(!a || !b)
}

fn main() {
	// import py2many.smt: no known V equivalent
	a := false
	b := false
	assert !demorgan(a, b)
	check_sat()
}
