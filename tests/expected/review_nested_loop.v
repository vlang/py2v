module main

fn inner() int {
	return 5
}

fn run() int {
	for i in []int{len: 1, init: index} {
		// pass
	}
	return inner()
}

fn main() {
	println(run())
}
