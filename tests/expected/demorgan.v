@[translated]
module main

fn demorgan(a bool, b bool) bool {
	a && b == !!a || !b
}

fn main() {
	// import py2many.smt: no known V equivalent
	a := bool{}
	b := bool{}
	assert !demorgan(a, b)
	check_sat()
}
