module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

pub struct Stack {
pub mut:
	stack []int
	names map[string]int
	rows  [][]f64
}

fn (mut self Stack) init() {
	self.stack = []int{}
	self.names = map[string]int{}
	self.rows = [][]f64{}
}

fn (mut self Stack) push(x int) {
	self.stack << x
}

fn (mut self Stack) tag(name string, n int) {
	self.names[name] = n
}

fn (mut self Stack) add_row(row []f64) {
	self.rows << row
}

fn (mut self Stack) pop() int {
	return self.stack.pop()
}

fn (mut self Stack) clear() {
	self.stack = []int{}
	self.names = map[string]int{}
}

pub fn py2v_new_stack() Stack {
	mut py2v_instance := Stack{}
	py2v_instance.init()
	return py2v_instance
}

fn main() {
	mut s := py2v_new_stack()
	s.push(3)
	s.push(4)
	s.tag('a', 1)
	s.add_row([1.5, 2.5])
	println(s.pop())
	println(s.stack)
	println(s.stack.len)
	println(s.names)
	println(s.rows)
	s.clear()
	println(s.stack)
	println(s.names.len)
}
