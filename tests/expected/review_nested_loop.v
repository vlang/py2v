module main

fn inner() int {
	return 5
}

fn run() int {
	for i in int(0) .. int(1) {
		// pass
	}
	return inner()
}

fn main() {
	println(run())
}
