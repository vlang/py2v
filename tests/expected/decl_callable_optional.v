module main

pub struct Handler {
pub mut:
	callback ?fn (int) int = none
}

fn (self Handler) run() int {
	return 3
}

fn main() {
	println(Handler{}.run())
}
