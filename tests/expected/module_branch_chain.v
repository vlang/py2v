module main

const py2v_branch_736372697074_1 = if check(1) {
	0
} else {
	if check(2) {
		1
	} else {
		if check(3) { 2 } else { 3 }
	}
}

const choose = if py2v_branch_736372697074_1 == 0 {
	py2v_branch_736372697074_2
} else {
	if py2v_branch_736372697074_1 == 1 {
		py2v_branch_736372697074_3
	} else {
		if py2v_branch_736372697074_1 == 2 {
			py2v_branch_736372697074_4
		} else {
			py2v_branch_736372697074_5
		}
	}
}

fn check(which int) bool {
	println(which)
	return which == 2
}

fn py2v_branch_736372697074_2(value int) int {
	return value + 10
}

fn py2v_branch_736372697074_3(value int) int {
	return value + 20
}

fn py2v_branch_736372697074_4(value int) int {
	return value + 30
}

fn py2v_branch_736372697074_5(value int) int {
	return value + 40
}

fn main() {
	previous := choose
	println(choose(1))
	println(previous(2))
}
