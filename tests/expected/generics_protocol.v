module main

pub struct Stack[T] {
pub mut:
	items []T
}

fn (mut self Stack[T]) init() {
	self.items = []T{}
}

fn (mut self Stack[T]) push(item T) {
	self.items << item
}

fn (mut self Stack[T]) pop() T {
	return self.items.pop()
}

fn (self Stack[T]) is_empty() bool {
	return self.items.len == 0
}

pub fn py2v_new_stack[T]() Stack[T] {
	mut py2v_instance := Stack[T]{}
	py2v_instance.init()
	return py2v_instance
}

interface Sized {}

fn first[T](mut stack Stack[T]) T {
	return stack.pop()
}

fn main() {
	mut s := py2v_new_stack()
	s.push(1)
	s.push(2)
	println(s.pop())
}
