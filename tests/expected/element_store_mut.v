module main

import pyrt

pub struct Point {
pub mut:
	x int
}

fn (mut self Point) init(x int) {
	self.x = x
}

pub fn py2v_new_point(x int) Point {
	mut py2v_instance := Point{}
	py2v_instance.init(x)
	return py2v_instance
}

pub struct Box {
pub mut:
	items &pyrt.ListRef[int] = &pyrt.ListRef[int]{}
}

fn (mut self Box) init(items &pyrt.ListRef[int]) {
	self.items = items
}

fn (mut self Box) put() {
	self.items.items[0] = 5
}

fn (mut self Box) bump() {
	self.items.items[1] += 5
}

pub fn py2v_new_box(items &pyrt.ListRef[int]) Box {
	mut py2v_instance := Box{}
	py2v_instance.init(items)
	return py2v_instance
}

fn main_func() {
	mut a := [int(1), 2]
	a[0] += 1
	println(a)
	mut counts := map[string]int{
		'x': 1
	}
	counts['x'] += 1
	println(counts['x'])
	mut grid := [[1, 2], [3, 4]]
	grid[0][1] = 5
	grid[1][0] = py2v_integer_mul1(grid[1][0], 3, 'element_store_mut.py:28', 'multiplication')
	println(grid)
	mut b := py2v_new_box(pyrt.list_ref[int]([1, 2]))
	b.put()
	b.bump()
	println(b.items.items.str())
	mut points := [py2v_new_point(1), py2v_new_point(2)]
	points[0].x = 7
	println(points[0].x)
	mut lists := map[string][]int{
		'a': [1, 2]
	}
	lists['a'][1] = 9
	println(lists['a'])
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_mul1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (a > 0 && ((b > 0 && a > max / b) || b < min / a)) || (a < 0 && ((b > 0 && a < min / b) || (b < 0 && a < max / b))) {
		py2v_integer_overflow1(site, operation)
	}
	return a * b
}

fn main() {
	main_func()
}
