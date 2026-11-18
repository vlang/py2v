module main

fn inner(v_ int) int {
	return v_
}

fn run() int {
	if true {
		// pass
	}
	return inner(9)
}

fn main() {
	println(run())
}
