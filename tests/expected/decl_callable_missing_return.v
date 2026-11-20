module main

import pyrt

type Any = pyrt.Value

pub struct Handler {
pub mut:
	callback fn (Any) Any
}

fn (self Handler) run() int {
	return 3
}

fn main() {
	println(Handler{}.run())
}
