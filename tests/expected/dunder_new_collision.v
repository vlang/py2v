module main

pub struct Item {
}

fn (self Item) py2v_dunder_new(cls int, value int) int {
	return value + 2
}

fn (self Item) new(value int) int {
	return value + 1
}

fn call_new(item Item, value int) int {
	return item.new(value)
}

fn call_allocator(item Item, value int) int {
	return item.py2v_dunder_new(0, value)
}

fn main() {
	println('loaded')
}
