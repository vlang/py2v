@[translated]
module main

__global latest = py2v_branch_736372697074_1

fn py2v_branch_736372697074_1(value int) int {
	return value + 10
}

fn from_body(value int) int {
	return latest(value)
}

fn py2v_branch_736372697074_2(value int) int {
	return value + 20
}

fn main() {
	saved := latest
	println(from_body(1))
	if from_body(2) == 12 {
		latest = py2v_branch_736372697074_2
	}
	println(from_body(1))
	println(saved(1))
}
