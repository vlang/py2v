module main

import pyrt

type Any = pyrt.Value

pub struct Stack {
pub mut:
	items []Any
}

fn (mut self Stack) init() {
	self.items = []Any{}
}

fn (mut self Stack) push(item Any) {
	self.items << item
}

fn (mut self Stack) push_pair(a int, b int) {
	self.items << pyrt.box([a, b])
}

fn (self Stack) size() int {
	return self.items.len
}

fn (self Stack) show() {
	println(pyrt.str(pyrt.box(self.items)))
	println(pyrt.str(self.items[0]))
}

pub fn py2v_new_stack() Stack {
	mut py2v_instance := Stack{}
	py2v_instance.init()
	return py2v_instance
}

fn mixed() []Any {
	mut items := []Any{}
	items << 1
	items << 'a'
	items << pyrt.box([1, 2])
	items << 2.5
	return items
}

fn main_func() {
	empty := []Any{}
	println(empty.len)
	items := mixed()
	println(items.len)
	mut row := []Any{}
	row << 7
	row << 'seven'
	row << pyrt.box([7, 7])
	println(row.len)
	println(pyrt.str(row[0]))
	println(pyrt.str(row[1]))
	for item in row {
		println(pyrt.str(item))
	}
	println(pyrt.str(pyrt.box(row)))
	if pyrt.eq(row[0], pyrt.box(7)) {
		println('first is seven')
	}
	println(pyrt.str(pyrt.plus(row[0], pyrt.box(1))))
	mut stack := py2v_new_stack()
	stack.push(3)
	stack.push('three')
	stack.push_pair(3, 4)
	println(stack.size())
	stack.show()
}

fn main() {
	main_func()
}
