module main

pub struct Thing {
pub mut:
	x int
}

fn (mut self Thing) init(x int) {
	self.x = x
}

fn main() {
	t := Thing{
		x: 1
	}
	println(t.x)
}
