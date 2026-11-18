module main

fn inner() int {
	return 4
}

fn run() int {
	if true {
		// pass
	}
	return inner()
}

fn main() {
	println(run())
}
