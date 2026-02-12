@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

pub struct Thing {
pub mut:
	x Any
}

fn (mut self Thing) __init__(x Any) {
	self.x = x
}

fn main() {
	t := Thing{
		x: 1
	}
	println((t.x).str())
}
