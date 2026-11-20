@[translated]
module py_pkg_runtime_binding

__global latest = py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_1

__global saved = py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_1

__global before int

__global after int

pub fn py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_1(value int) int {
	return value + 10
}

pub fn from_body(value int) int {
	return latest(value)
}

pub fn total() int {
	return after + saved(1)
}

pub fn py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_2(value int) int {
	return value + 20
}

fn py2v_startup_choice_1() {
	saved = latest
	before = from_body(1)
	println(before)
	if from_body(2) == 12 {
		latest = py2v_branch_706b675f72756e74696d655f62696e64696e672e63686f696365_2
	}
	after = from_body(1)
}

fn init() {
	py2v_startup_choice_1()
}
