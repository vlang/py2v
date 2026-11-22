module main

const py2v_branch_736372697074_1 = if option() { true } else { false }

const choose = if py2v_branch_736372697074_1 {
	py2v_branch_736372697074_2
} else {
	py2v_branch_736372697074_3
}

const offset = if py2v_branch_736372697074_1 {
	py2v_branch_736372697074_4
} else {
	py2v_branch_736372697074_5
}

fn option() bool {
	println('select')
	return false
}

fn py2v_branch_736372697074_2(value int) int {
	return value + 1
}

fn py2v_branch_736372697074_3(value int) int {
	return value + 2
}

fn py2v_branch_736372697074_4() int {
	return 10
}

fn py2v_branch_736372697074_5() int {
	return 20
}

fn use(value int) int {
	return choose(value) + offset()
}

fn main() {
	saved := choose
	println('${saved(5)} ${use(6)}')
}
