module main

pub struct Stack[T] {
pub mut:
	items []T
}

fn (mut self Stack[T]) __init__() {
	self.items = []T{}
}

fn (self Stack[T]) push(item T) {
	self.items << item
}

fn (self Stack[T]) pop() T {
	return self.items.pop()
}

fn (self Stack[T]) is_empty() bool {
	return self.items.len == 0
}

interface Sized {
	__len__() int
}

fn first(stack Stack[T]) T {
	return stack.pop()
}

fn main() {
	s := Stack{}
	s.push(1)
	s.push(2)
	println(s.pop())
}
