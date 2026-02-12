@[translated]
module main

__global (
	a = bool{}
	b = bool{}
)
fn demorgan(a bool, b bool) bool {
	a && b == !(!a || !b)
}

fn main() {
	assert !(demorgan(a, b))
	check_sat()
}
